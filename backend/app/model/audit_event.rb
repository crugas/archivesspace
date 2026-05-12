require 'securerandom'

class AuditEvent
  W3C_URL = 'https://www.w3.org/ns/activitystreams'
  ACTIVITY_STREAM_URI = '/activity-stream'

  PAGE_SIZE = 2

  # FIXME: which object types do we want?
  # others include: assessment, classification, collection_management
  #                 container_profile, default_values, digital_object_component
  #                 enumeration, event, group, job, location, location_profile
  #                 merge_request, ..., subject, user, vocabulary
  OBJECT_TYPES =
    [
     OBJECT_TYPE_REPOSITORY = 1,
     OBJECT_TYPE_AGENT_PERSON = 2,
     OBJECT_TYPE_AGENT_FAMILY = 3,
     OBJECT_TYPE_AGENT_CORPORATE_ENTITY = 4,
     OBJECT_TYPE_AGENT_SOFTWARE = 5,
     OBJECT_TYPE_ACCESSION = 6,
     OBJECT_TYPE_RESOURCE = 7,
     OBJECT_TYPE_ARCHIVAL_OBJECT = 8,
     OBJECT_TYPE_DIGITAL_OBJECT = 9,
     OBJECT_TYPE_TOP_CONTAINER = 10,
    ]

  OBJECT_TYPE_CODE_TABLE =
    {
     OBJECT_TYPE_REPOSITORY => 'repository',
     OBJECT_TYPE_AGENT_PERSON => 'agent_person',
     OBJECT_TYPE_AGENT_FAMILY => 'agent_family',
     OBJECT_TYPE_AGENT_CORPORATE_ENTITY => 'agent_corporate_entity',
     OBJECT_TYPE_AGENT_SOFTWARE => 'agent_software',
     OBJECT_TYPE_ACCESSION => 'accession',
     OBJECT_TYPE_RESOURCE => 'resource',
     OBJECT_TYPE_ARCHIVAL_OBJECT => 'archival_object',
     OBJECT_TYPE_DIGITAL_OBJECT => 'digital_object',
     OBJECT_TYPE_TOP_CONTAINER => 'top_container',
    }

  # a subset of the types in the standard
  # thinking Add and Remove for publish and unpublish?
  SUPPORTED_ACTIVITY_TYPES =
    [
     ACTIVITY_TYPE_ADD = 1,
     ACTIVITY_TYPE_CREATE = 2,
     ACTIVITY_TYPE_DELETE = 3,
     ACTIVITY_TYPE_MOVE = 4,
     ACTIVITY_TYPE_REMOVE = 5,
     ACTIVITY_TYPE_UPDATE = 6
    ]

  EXTENSION_ACTIVITY_TYPES =
    [
     ACTIVITY_TYPE_MERGE = 51
    ]

  ACTIVITY_TYPES = SUPPORTED_ACTIVITY_TYPES + EXTENSION_ACTIVITY_TYPES

  ACTIVITY_TYPE_CODE_TABLE =
    {
     ACTIVITY_TYPE_ADD => 'Add',
     ACTIVITY_TYPE_CREATE => 'Create',
     ACTIVITY_TYPE_DELETE => 'Delete',
     ACTIVITY_TYPE_MOVE => 'Move',
     ACTIVITY_TYPE_REMOVE => 'Remove',
     ACTIVITY_TYPE_UPDATE => 'Update',
     ACTIVITY_TYPE_MERGE => 'Merge'
    }


  # FIXME: these are the examples given in the scope statement - needs thought
  # this field is not in the standard
  CHANGE_METHODS =
    [
     CHANGE_METHOD_API = 1,
     CHANGE_METHOD_BULK = 2,
     CHANGE_METHOD_RAPID = 3
    ]

  CHANGE_METHOD_CODE_TABLE =
    {
     CHANGE_METHOD_API => 'API',
     CHANGE_METHOD_BULK => 'Bulk Spreadsheet',
     CHANGE_METHOD_RAPID => 'Rapid Data Entry'
    }

  ACTOR_TYPES =
    [
     ACTOR_TYPE_APPLICATION = 1,
     ACTOR_TYPE_PERSON = 2,
     ACTOR_TYPE_SERVICE = 3
    ]

  ACTOR_TYPE_CODE_TABLE =
    {
     ACTOR_TYPE_APPLICATION => 'Application',
     ACTOR_TYPE_PERSON => 'Person',
     ACTOR_TYPE_SERVICE => 'Service'
    }


  def self.ds(db, since = 0, object_type = nil)
    ds = db[:audit_event].order(Sequel.desc(:audit_event__timestamp))

    if since > 0
      since_time = Time.at(since)
      ds = ds.where { timestamp >= since_time }
    end

    if object_type
      ds = ds.filter(:object_type => OBJECT_TYPE_CODE_TABLE.invert[object_type])
    end

    ds.select(:uuid,
              :timestamp,
              :actor_name,
              :actor_type,
              :object_uri,
              :object_type,
              :origin_uri,
              :target_uri,
              :activity_type,
              :change_method)
  end


  def self.render(event)
    out = {
      '@context' => W3C_URL,
      :id => "#{ACTIVITY_STREAM_URI}/event/#{event[:uuid]}",
      :endTime => event[:timestamp].rfc3339,
      :actor => {
        :type => ACTOR_TYPE_CODE_TABLE[event[:actor_type]],
        :name => event[:actor_name]
      },
      :object => {
        :id => event[:object_uri],
        :type => OBJECT_TYPE_CODE_TABLE[event[:object_type]]
      },
      :type => ACTIVITY_TYPE_CODE_TABLE[event[:activity_type]],
      :method_of_change => CHANGE_METHOD_CODE_TABLE[event[:change_method]]
    }

    if event.fetch(:origin_uri)
      out[:origin] = {
        :id => event[:origin_uri]
      }
    end

    if event.fetch(:target_uri)
      out[:target] = {
        :id => event[:target_uri]
      }
    end

    out
  end

  def self.events_since(since, object_type = nil)
    DB.open do |db|
      ds(db, since, object_type).map{|row| render(row)}
    end
  end

  def self.by_id(uuid)
    DB.open do |db|
      render(ds(db).filter(:uuid => uuid).first)
    end
  end

  def self.by_type(object_type)
    DB.open do |db|
      ds(db, 0, object_type).map{|row| render(row)}
    end
  end

  def self.all_activity_streams
    AuditEvent::OBJECT_TYPE_CODE_TABLE.values.map{|ot| "#{ACTIVITY_STREAM_URI}/#{ot}"}

  end

  def self.activity_stream(object_type = nil)
    DB.open do |db|
      total = ds(db, 0, object_type).count
      last_page = (total.to_f / PAGE_SIZE).ceil
      uri = ACTIVITY_STREAM_URI
      if object_type
        uri += "/#{object_type}"
      end

      {
        '@context' => W3C_URL,
        :type => 'OrderedCollection',
        :totalItems => total,
        :first => "#{uri}/page/1",
        :last => "#{uri}/page/#{last_page}",
      }
    end
  end

  def self.page(page, object_type = nil)
    DB.open do |db|
      uri = ACTIVITY_STREAM_URI
      if object_type
        uri += "/#{object_type}"
      end

      out = {
        '@context' => W3C_URL,
        :type => 'OrderedCollectionPage',
        :id => "#{uri}/page/#{page}",
        :partOf => {
          :id => uri,
          :type => 'OrderedCollection'
        }
      }

      if page > 1
        out[:prev] = {
          :id => "#{uri}/page/#{page - 1}",
          :type => 'OrderedCollectionPage',
        }
      end

      out[:orderedItems] = ds(db, 0, object_type).limit(PAGE_SIZE, (page - 1) * PAGE_SIZE).map{|row| render(row)}

      out
    end
  end


  def self.log_event(activity_type, change_method, object_uri, opts = {})
    log_events(activity_type, change_method, [object_uri], opts = opts)
  end

  def self.log_events(activity_type, change_method, object_uris, opts = {})
    unless ACTIVITY_TYPES.include?(activity_type)
      Log.info("Failed to log Audit Event - unsupported Activity Type: #{ACTIVITY_TYPE_CODE_TABLE[activity_type]}")
      return
    end

    unless opts[:actor]
      if username = RequestContext.get(:current_username)
        opts[:actor] = username
      else
        Log.info("Failed to log Audit Event - no Actor provided and no current username")
        return
      end
    end

    DB.open do |db|
      object_uris.each do |uri|
        parsed = JSONModel.parse_reference(uri)

        if parsed.nil?
          Log.info("Failed to log Audit Event - failed to parse Object URI: #{uri}")
          next
        end

        unless OBJECT_TYPE_CODE_TABLE.values.include?(parsed[:type])
          Log.info("Failed to log Audit Event - unsupported Object Type: #{parsed[:type]}")
          next
        end

        db[:audit_event].insert(:uuid => SecureRandom.uuid,
                                :timestamp => Time.now,
                                :actor_name => opts[:actor],
                                :actor_type => opts[:actor_type] || ACTOR_TYPE_PERSON,
                                :object_uri => uri,
                                :object_type => OBJECT_TYPE_CODE_TABLE.invert[parsed[:type]],
                                :origin_uri => opts[:origin_uri],
                                :target_uri => opts[:target_uri],
                                :activity_type => activity_type,
                                :change_method => change_method)
      end
    end
  end
end

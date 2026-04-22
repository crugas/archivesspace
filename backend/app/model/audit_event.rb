require 'securerandom'

class AuditEvent
  W3C_URL = 'https://www.w3.org/ns/activitystreams'

  PAGE_SIZE = 2

  OBJECT_TYPES =
    [
     OBJECT_TYPE_RESOURCE = 'resource',
     OBJECT_TYPE_ARCHIVAL_OBJECT = 'archival_object'
    ]

  # a subset of the types in the standard
  # thinking Add and Remove for publish and unpublish?
  SUPPORTED_ACTIVITY_TYPES =
    [
     ACTIVITY_TYPE_ADD = 'Add',
     ACTIVITY_TYPE_CREATE = 'Create',
     ACTIVITY_TYPE_DELETE = 'Delete',
     ACTIVITY_TYPE_MOVE = 'Move',
     ACTIVITY_TYPE_REMOVE = 'Remove',
     ACTIVITY_TYPE_UPDATE = 'Update'
    ]

  EXTENSION_ACTIVITY_TYPES =
    [
     ACTIVITY_TYPE_MERGE = 'Merge'
    ]

  ACTIVITY_TYPES = (SUPPORTED_ACTIVITY_TYPES + EXTENSION_ACTIVITY_TYPES).sort

  # FIXME: these are the examples given in the scope statement - needs thought
  # this field is not in the standard
  CHANGE_METHODS =
    [
     CHANGE_METHOD_API = 'API',
     CHANGE_METHOD_BULK = 'Bulk Spreadsheet',
     CHANGE_METHOD_RAPID = 'Rapid Data Entry'
    ]

  AGENT_TYPES =
    [
     AGENT_TYPE_APPLICATION = 'Application',
     AGENT_TYPE_PERSON = 'Person',
     AGENT_TYPE_SERVICE = 'Service'
    ]


  def self.ds(db, since = 0, object_type = nil)
    ds = db[:audit_event].order(Sequel.desc(:audit_event__timestamp))

    if since > 0
      since_time = Time.at(since)
      ds = ds.where { timestamp >= since_time }
    end

    if object_type
      ds = ds.filter(:object_type => object_type)
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
      :id => "/activity-stream/event/#{event[:uuid]}",
      :endTime => event[:timestamp].rfc3339,
      :actor => {
        :type => event[:actor_type] || 'Person',
        :name => event[:actor_name]
      },
      :object => {
        :id => event[:object_uri],
        :type => event[:object_type]
      },
      :type => event[:activity_type],
      :method_of_change => event[:change_method]
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

  def self.activity_stream(object_type = nil)
    DB.open do |db|
      total = ds(db, 0, object_type).count
      last_page = (total.to_f / PAGE_SIZE).ceil
      uri = '/activity-stream'
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
      uri = '/activity-stream'
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
      Log.info("Failed to log Audit Event - unsupported Activity Type: #{activity_type}")
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

        unless AuditEvent::OBJECT_TYPES.include?(parsed[:type])
          Log.info("Failed to log Audit Event - unsupported Object Type: #{parsed[:type]}")
          next
        end

        db[:audit_event].insert(:uuid => SecureRandom.uuid,
                                :timestamp => Time.now,
                                :actor_name => opts[:actor],
                                :actor_type => opts[:actor_type],
                                :object_uri => uri,
                                :object_type => parsed[:type],
                                :origin_uri => opts[:origin_uri],
                                :target_uri => opts[:target_uri],
                                :activity_type => activity_type,
                                :change_method => change_method)
      end
    end
  end
end

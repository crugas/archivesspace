require 'securerandom'

class AuditEvent
  W3C_URL = 'https://www.w3.org/ns/activitystreams'
  # FIXME: might need to support a proxy url
  ARCHIVESSPACE_URI = AppConfig[:backend_url]

  PAGE_SIZE = AppConfig[:activity_stream_page_size].to_i


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
     OBJECT_TYPE_SUBJECT = 11,
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
     OBJECT_TYPE_SUBJECT => 'subject',
    }

  # a subset of the types in the standard
  # FIXME: no special handling for publish - just an update
  ACTIVITY_TYPES =
    [
     ACTIVITY_TYPE_ADD = 1,
     ACTIVITY_TYPE_CREATE = 2,
     ACTIVITY_TYPE_DELETE = 3,
     ACTIVITY_TYPE_MOVE = 4,
     ACTIVITY_TYPE_REMOVE = 5,
     ACTIVITY_TYPE_UPDATE = 6
    ]

  ACTIVITY_TYPE_CODE_TABLE =
    {
     ACTIVITY_TYPE_ADD => 'Add',
     ACTIVITY_TYPE_CREATE => 'Create',
     ACTIVITY_TYPE_DELETE => 'Delete',
     ACTIVITY_TYPE_MOVE => 'Move',
     ACTIVITY_TYPE_REMOVE => 'Remove',
     ACTIVITY_TYPE_UPDATE => 'Update',
    }

  CHANGE_METHODS =
    [
     CHANGE_METHOD_API = 1,
     CHANGE_METHOD_FORM = 2,
     CHANGE_METHOD_IMPORTER = 3,
     CHANGE_METHOD_JOB = 4,
     CHANGE_METHOD_BULK = 5,
     CHANGE_METHOD_RAPID = 6,
     CHANGE_METHOD_MIGRATION = 7,
    ]

  CHANGE_METHOD_CODE_TABLE =
    {
     CHANGE_METHOD_API => 'API',
     CHANGE_METHOD_FORM => 'Staff UI Form',
     CHANGE_METHOD_IMPORTER => 'Importer',
     CHANGE_METHOD_JOB => 'Background Job',
     CHANGE_METHOD_BULK => 'Bulk Spreadsheet',
     CHANGE_METHOD_RAPID => 'Rapid Data Entry',
     CHANGE_METHOD_MIGRATION => 'Database Migration',
    }

  ROLES =
    [
     ROLE_OBJECT = 1,
     ROLE_SOURCE = 2,
     ROLE_TARGET = 3
    ]

  ROLE_CODE_TABLE =
    {
     ROLE_OBJECT => 'object',
     ROLE_SOURCE => 'source',
     ROLE_TARGET => 'target'
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


  def self.ds(db, since = nil, object_type = nil)
    ds = db[:audit_event].left_join(:audit_record, :audit_record__audit_event_id => :audit_event__id)
                         .group(:audit_event__id)
                         .order(Sequel.asc(:audit_event__timestamp))

    unless since.nil?
      since_time = Time.at(since)
      ds = ds.where { timestamp >= since_time }
    end

    if object_type
      ds = ds.filter(:audit_record__type => object_type)
    end

    ds.select(:uuid,
              :timestamp,
              :actor_name,
              :actor_type,
              :activity_type,
              :change_method,
              Sequel.function(:GROUP_CONCAT, Sequel.function(:CONCAT_WS, ":", :audit_record__role, :audit_record__type, :audit_record__uri)).as(:records))
  end

  def self.archivesspace_uri(uri = '')
    if (AppConfig[:activity_stream_use_relative_uris] rescue false)
      uri
    else
      "#{ARCHIVESSPACE_URI}#{uri}"
    end
  end

  def self.activity_stream_uri(uri = '')
    archivesspace_uri("/activity-stream#{uri}")
  end

  def self.render(event)
    out = {
      '@context' => W3C_URL,
      :id => activity_stream_uri("/event/#{event[:uuid]}"),
      :endTime => event[:timestamp].rfc3339,
      :actor => {
        :type => ACTOR_TYPE_CODE_TABLE[event[:actor_type]],
        :name => event[:actor_name]
      },
      :type => ACTIVITY_TYPE_CODE_TABLE[event[:activity_type]],
      :method_of_change => CHANGE_METHOD_CODE_TABLE[event[:change_method]]
    }

    records = {}

    event[:records].split(',').each do |record|
      (role, type, uri) = record.split(':')
      records[role] ||= []
      records[role] << {:uri => uri, :type => type}
    end

    records.each do |role, uris|
      out[ROLE_CODE_TABLE[role.to_i]] = ASUtils.wrap(uris).map{|uri|
        {
          :id => archivesspace_uri(uri[:uri]),
          :type => uri[:type]
        }
      }

      if uris.length == 1
        out[ROLE_CODE_TABLE[role.to_i]] = out[ROLE_CODE_TABLE[role.to_i]].first
      end
    end

    # Special handling for merges
    # A merge is a special case of move where the target is included in the list of objects
    # This is marked with a summary of 'merge'
    if out[:type] == ACTIVITY_TYPE_CODE_TABLE[ACTIVITY_TYPE_MOVE] &&
        ASUtils.wrap(out[ROLE_CODE_TABLE[ROLE_OBJECT]]).map{|o| o[:id]}.include?(out[ROLE_CODE_TABLE[ROLE_TARGET]][:id])
      out[:summary] = 'merge'
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
      ds(db, nil, object_type).map{|row| render(row)}
    end
  end

  def self.all_activity_streams
    AuditEvent::OBJECT_TYPE_CODE_TABLE.values.map{|ot| activity_stream_uri("/#{ot}")}
  end

  def self.activity_stream(object_type = nil)
    DB.open do |db|
      total = ds(db, nil, object_type).count
      last_page = (total.to_f / PAGE_SIZE).ceil
      uri = activity_stream_uri
      if object_type
        uri += "/#{object_type}"
      end

      {
        '@context' => W3C_URL,
        :type => 'OrderedCollection',
        :totalItems => total,
        :first => activity_stream_uri("/page/1"),
        :last => activity_stream_uri("/page/#{last_page}"),
      }
    end
  end

  def self.page(page, object_type = nil)
    DB.open do |db|
      uri = activity_stream_uri
      if object_type
        uri += "/#{object_type}"
      end

      out = {
        '@context' => W3C_URL,
        :type => 'OrderedCollectionPage',
        :id => "/#{uri}/page/#{page}",
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

      out[:orderedItems] = ds(db, nil, object_type).limit(PAGE_SIZE, (page - 1) * PAGE_SIZE).map{|row| render(row)}

      out
    end
  end

  def self.log_event(activity_type, change_method, records, opts = {})
    return unless AppConfig[:enable_audit_logging]

    unless ACTIVITY_TYPES.include?(activity_type)
      Log.warn("Failed to log Audit Event - unsupported Activity Type: #{ACTIVITY_TYPE_CODE_TABLE[activity_type]}")
      return
    end

    unless opts[:actor]
      if username = RequestContext.get(:current_username)
        opts[:actor] = username
      else
        Log.warn("Failed to log Audit Event - no Actor provided and no current username")
        return
      end
    end

    DB.open do |db|
      event_id = db[:audit_event].insert(:uuid => SecureRandom.uuid,
                                         :timestamp => Time.now,
                                         :actor_name => opts[:actor],
                                         :actor_type => opts[:actor_type] || ACTOR_TYPE_PERSON,
                                         :activity_type => activity_type,
                                         :change_method => change_method)


      records.each do |role, uris|
        ASUtils.wrap(uris).each do |uri|
          parsed = JSONModel.parse_reference(uri)

          if parsed.nil?
            Log.warn("Failed to log Audit Event - failed to parse URI: #{uri}")
            next
          end

          unless OBJECT_TYPE_CODE_TABLE.values.include?(parsed[:type])
            Log.warn("Failed to log Audit Event - unsupported Object Type: #{parsed[:type]}")
            next
          end

          db[:audit_record].insert(:audit_event_id => event_id,
                                   :uri => uri,
                                   :type => parsed[:type],
                                   :role => role)

        end
      end
    end
  end
end

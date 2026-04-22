require 'securerandom'

class AuditEvent

  RECORD_TYPES =
    [
     RECORD_TYPE_RESOURCE = 'resource',
     RECORD_TYPE_ARCHIVAL_OBJECT = 'archival_object'
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
      '@context' => 'https://www.w3.org/ns/activitystreams',
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


  def self.log_event(actor, activity_type, change_method, object_uris, opts = {})
    unless ACTIVITY_TYPES.include?(activity_type)
      Log.info("Failed to log Audit Event - unsupported Activity Type: #{activity_type}")
      return
    end

    DB.open do |db|
      object_uris.each do |uri|
        parsed = JSONModel.parse_reference(uri)

        if parsed.nil?
          Log.info("Failed to log Audit Event - failed to parse Object URI: #{uri}")
          next
        end

        unless AuditEvent::RECORD_TYPES.include?(parsed[:type])
          Log.info("Failed to log Audit Event - unsupported Record Type: #{parsed[:type]}")
          next
        end

        db[:audit_event].insert(:uuid => SecureRandom.uuid,
                                :timestamp => Time.now,
                                :actor_name => actor,
                                :actor_type => opts.fetch(:actor_type, nil),
                                :object_uri => uri,
                                :object_type => parsed[:type],
                                :origin_uri => opts.fetch(:origin_uri, nil),
                                :target_uri => opts.fetch(:target_uri, nil),
                                :activity_type => activity_type,
                                :change_method => change_method)
      end
    end
  end
end

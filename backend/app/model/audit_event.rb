require 'audit_event_constants'

require 'securerandom'

class AuditEvent
  W3C_URL = 'https://www.w3.org/ns/activitystreams'
  # FIXME: might need to support a proxy url
  ARCHIVESSPACE_URI = AppConfig[:backend_url]

  PAGE_SIZE = AppConfig[:activity_stream_page_size].to_i

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

      if total == 0
        {
          '@context' => W3C_URL,
          :type => 'OrderedCollection',
          :totalItems => total,
        }
      else
        {
          '@context' => W3C_URL,
          :type => 'OrderedCollection',
          :totalItems => total,
          :first => uri + "/page/1",
          :last => uri + "/page/#{last_page}",
        }
      end
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

      if page < (ds(db, nil, object_type).count.to_f / PAGE_SIZE).ceil
        out[:next] = {
          :id => "#{uri}/page/#{page + 1}",
          :type => 'OrderedCollectionPage',
        }
      end

      ids = ds(db, nil, object_type).select(:audit_event__id).limit(PAGE_SIZE, (page - 1) * PAGE_SIZE).map{|row| row[:id]}
      out[:orderedItems] = ds(db, nil, object_type).filter(:audit_event__id => ids).map{|row| render(row)}

      out
    end
  end

  def self.lookup_change_method(key)
    CHANGE_METHOD_LOOKUP.fetch(key) {
      if key
        Log.warn("Failed attempt to lookup AuditEvent::CHANGE_METHOD with key: #{key}. Defaulting to API")
      end
      CHANGE_METHOD_API
    }
  end

  def self.log_event(activity_type, records, opts = {})
    return unless AppConfig[:enable_audit_logging]

    if records.values.flatten.compact.empty?
      # Don't log an event if there are no affected records
      # This can happen when nested records are updated, via create_from_json
      return
    end

    unless ACTIVITY_TYPES.include?(activity_type)
      Log.warn("Failed to log Audit Event - unsupported Activity Type: #{activity_type}")
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

    records_to_be_logged = {}

    records.each do |role, uris|
      ASUtils.wrap(uris).each do |uri|
        parsed = JSONModel.parse_reference(uri)

        if parsed.nil?
          Log.warn("Failed to log Audit Event Record - failed to parse URI: #{uri}")
          next
        end

        unless OBJECT_TYPE_CODE_TABLE.values.include?(parsed[:type])
          Log.debug("Skipping Audit Record - unsupported Object Type: #{parsed[:type]}")
          next
        end

        records_to_be_logged[role] ||= []
        records_to_be_logged[role] << {:uri => uri, :type => parsed[:type]}
      end
    end

    if records_to_be_logged.empty?
      return
    end

    change_method = RequestContext.get(:change_method) || CHANGE_METHOD_API

    DB.open do |db|
      event_id = db[:audit_event].insert(:uuid => SecureRandom.uuid,
                                         :timestamp => Time.now,
                                         :actor_name => opts[:actor],
                                         :actor_type => opts[:actor_type] || ACTOR_TYPE_PERSON,
                                         :activity_type => activity_type,
                                         :change_method => change_method)

      records_to_be_logged.each do |role, records|
        records.each do |record|
          db[:audit_record].insert(:audit_event_id => event_id,
                                   :uri => record[:uri],
                                   :type => record[:type],
                                   :role => role)
        end
      end
    end
  end
end

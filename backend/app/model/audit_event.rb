require 'securerandom'

class AuditEvent

  RECORD_TYPES = ['resource', 'archival_object']

  def self.ds(db, since = 0, record_type = nil)
    ds = db[:audit_event].left_join(:audit_record, :audit_record__audit_event_id => :audit_event__id)
                         .group(:audit_event__id)
                         .order(Sequel.desc(:audit_event__timestamp))

    if since > 0
      since_time = Time.at(since)
      ds = ds.where { timestamp >= since_time }
    end

    if record_type
      ds = ds.filter(:audit_record__record_type => record_type)
    end

    ds.select(:uuid,
              :timestamp,
              :actor,
              :activity_type,
              :change_method,
              Sequel.function(:GROUP_CONCAT, :audit_record__target_uri).as(:records))
  end

  def self.render(event)
    {
      :uuid => event[:uuid],
      :timestamp => event[:timestamp],
      :actor => event[:actor],
      :activity_type => event[:activity_type],
      :change_method => event[:change_method],
      :records => event[:records].split(',')
    }
  end

  def self.events_since(since, record_type = nil)
    DB.open do |db|
      ds(db, since, record_type).map{|row| render(row)}
    end
  end

  def self.by_id(uuid)
    DB.open do |db|
      render(ds(db).filter(:uuid => uuid).first)
    end
  end

  def self.by_type(record_type)
    DB.open do |db|
      ds(db, 0, record_type).map{|row| render(row)}
    end
  end



  def self.new_event(actor, activity_type, change_method, record_uris, opts = {})
    uris = record_uris.map{|uri|
      source_uri = nil
      target_uri = uri
      if uri.is_a?(Array)
        source_uri = uri.first
        target_uri = uri.last
      end
      {
        :source_uri => source_uri,
        :target_uri => target_uri,
        :parsed => JSONModel.parse_reference(target_uri)
      }
    }.select{|uri| AuditEvent::RECORD_TYPES.include?(uri[:parsed][:type])}

    unless uris.empty?
      DB.open do |db|
        event_id = db[:audit_event].insert(:uuid => SecureRandom.uuid,
                                           :timestamp => Time.now,
                                           :actor => actor,
                                           :source_repo_uri => opts.fetch('source_repo_uri', nil),
                                           :target_repo_uri => opts.fetch('target_repo_uri', nil),
                                           :activity_type => activity_type,
                                           :change_method => change_method)

        uris.each do |uri|
          # FIXME: multi_insert?
          db[:audit_record].insert(:audit_event_id => event_id,
                                   :record_type => uri[:parsed][:type],
                                   :source_uri => uri[:source_uri],
                                   :target_uri => uri[:target_uri])
        end
      end
    end
  end
end

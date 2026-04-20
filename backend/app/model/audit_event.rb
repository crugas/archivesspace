class AuditEvent

  RECORD_TYPES = ['resource', 'archival_object']

  def self.events_since(since, record_type = nil)
    since_time = Time.at(since)

    DB.open do |db|
      db[:audit_event].where { timestamp >= since_time }
        .order(Sequel.desc(:timestamp))
        .map do |event|
        {
          :timestamp => event[:timestamp],
          :actor => event[:actor],
          :activity_type => event[:activity_type],
          :change_method => event[:change_method],
          :records => db[:audit_record].filter(:audit_event_id => event[:id]).select_map(:target_uri)
        }
      end
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
        event_id = db[:audit_event].insert(:timestamp => Time.now,
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

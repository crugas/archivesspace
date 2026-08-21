require_relative 'utils'

Sequel.migration do
  no_audit_events_required!

  up do
    now = Time.now
    [:accession, :archival_object, :resource].each do |table|
      self[table].update(:system_mtime => now)
    end
  end


  down do
  end

end

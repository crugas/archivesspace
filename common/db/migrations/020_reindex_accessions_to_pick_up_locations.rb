require_relative 'utils'

Sequel.migration do
  no_audit_events_required!

  up do
    self[:accession].update(:system_mtime => Time.now)
  end


  down do
  end

end

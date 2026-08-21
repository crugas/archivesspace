require_relative 'utils'

Sequel.migration do
  no_audit_events_required!

  up do
    self[:event].update(:system_mtime => Time.now)
  end


  down do
  end

end

require_relative 'utils'

Sequel.migration do
  no_audit_events_required!

  up do
    [:location].each do |table|
      self[table].update(:system_mtime => Time.now)
    end
  end


  down do
  end

end

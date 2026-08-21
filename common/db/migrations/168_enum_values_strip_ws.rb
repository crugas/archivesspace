require_relative 'utils'

Sequel.migration do
  no_audit_events_required!

  up do
    self[:enumeration_value].update(value: Sequel.trim(:value))
  end

  down do
  end

end

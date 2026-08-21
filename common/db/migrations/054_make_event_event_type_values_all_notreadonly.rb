require_relative 'utils'

Sequel.migration do
  no_audit_events_required!

  up do
    list = self[:enumeration].filter(:name => 'event_event_type').get(:id)
    self[:enumeration_value].filter(:enumeration_id => list).update(:readonly => 0 )
  end
end

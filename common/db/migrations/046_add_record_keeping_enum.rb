require_relative 'utils'

Sequel.migration do
  no_audit_events_required!

  up do
    term = "record_keeping"
    enum = self[:enumeration].filter(:name => 'date_label').select(:id).first[:id]
    counter = self[:enumeration_value].filter(:enumeration_id => enum).order(:position).select(:position).last[:position]

    unless self[:enumeration_value].filter(:enumeration_id => enum, :value => term).count > 0
      self[:enumeration_value].insert( :enumeration_id => enum, :value => term, :readonly => 0, :position => counter + 1)
    end

  end


  down do
  end

end

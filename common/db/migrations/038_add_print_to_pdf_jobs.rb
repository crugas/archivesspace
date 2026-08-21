require_relative 'utils'

Sequel.migration do
  no_audit_events_required!

  up do
    enum = self[:enumeration].filter(:name => "job_type").select(:id)
    self[:enumeration_value].insert(:enumeration_id => enum, :value => "print_to_pdf_job", :readonly => 1 )
  end

end

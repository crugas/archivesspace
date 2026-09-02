Sequel.migration do
  no_audit_events_required!

  up do
    create_table(:audit_enabled_tracking) do
      primary_key :id
      DateTime :startup_time, null: false, index: true
      Integer :audit_enabled, null: false
    end
  end
end

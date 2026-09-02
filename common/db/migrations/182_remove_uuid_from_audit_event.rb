Sequel.migration do
  no_audit_events_required!

  up do
    alter_table(:audit_event) do
      drop_column(:uuid)
    end
  end
end

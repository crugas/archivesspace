require_relative 'utils'

Sequel.migration do
  no_audit_events_required!

  up do
    alter_table(:top_container) do
      add_column(:internal_note, String)
    end
  end

  down do
  end

end

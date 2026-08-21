require_relative 'utils'

Sequel.migration do
  no_audit_events_required!

  up do
    alter_table(:repository) do
      TextField :description
    end
  end

  down do
    alter_table(:repository) do
      drop_column(:description)
    end
  end

end

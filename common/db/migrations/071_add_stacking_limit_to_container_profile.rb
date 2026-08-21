require_relative 'utils'

Sequel.migration do
  no_audit_events_required!

  up do
    alter_table(:container_profile) do
      add_column(:stacking_limit, String, :null => true)
    end
  end


  down do
    alter_table(:container_profile) do
      drop_column(:stacking_limit)
    end
  end

end

Sequel.migration do
  up do
    create_table(:audit_event) do
      primary_key :id
      DateTime :timestamp, :null => false
      String :actor, :null => false
      String :source_repo_uri
      String :target_repo_uri
      String :activity_type, :null => false
      String :change_method, :null => false
    end

    create_table(:audit_record) do
      primary_key :id
      Integer :audit_event_id, :null => false
      String :record_type, :null => false
      String :source_uri
      String :target_uri, :null => false
    end

    alter_table(:audit_record) do
      add_foreign_key([:audit_event_id], :audit_event, :key => :id)
    end
  end
end

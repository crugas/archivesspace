Sequel.migration do
  up do
    create_table(:audit_event) do
      primary_key :id
      String :uuid, :null => false
      DateTime :timestamp, :null => false
      String :actor_name, :null => false
      String :actor_type
      String :object_uri, :null => false
      String :object_type, :null => false
      String :origin_uri
      String :target_uri
      String :activity_type, :null => false
      String :change_method, :null => false
    end
  end
end

Sequel.migration do
  up do
    create_table(:audit_event) do
      primary_key :id
      String :uuid, :null => false
      DateTime :timestamp, :null => false
      column :activity_type, :tinyint, :unsigned => true, :null => false
      column :change_method, :tinyint, :unsigned => true, :null => false
      String :actor_name, :null => false
      column :actor_type, :tinyint, :unsigned => true, :null => false
      String :object_uri, :null => false
      column :object_type, :tinyint, :unsigned => true, :null => false
      String :origin_uri
      String :target_uri
    end
  end
end

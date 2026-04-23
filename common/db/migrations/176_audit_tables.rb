Sequel.migration do
  up do
    create_table(:audit_event) do
      primary_key :id
      String :uuid, :null => false
      DateTime :timestamp, :null => false
      Integer :activity_type, :null => false, :size => :tinyint
      Integer :change_method, :null => false, :size => :tinyint
      String :actor_name, :null => false
      Integer :actor_type, :null => false, :size => :tinyint
      String :object_uri, :null => false
      Integer :object_type, :null => false, :size => :tinyint
      String :origin_uri
      String :target_uri
    end
  end
end

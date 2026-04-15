Sequel.migration do
  up do
    create_table(:audit) do
      # From the spec:
      # Timestamp
      # User/actor
      # Affected record(s) identifiers (URIs)
      # Activity type
      # Method of change (bulk spreadsheet, API, rapid data entry, etc.)

      primary_key :id

      # Timestamp
      # prefer an int timestamp?
      DateTime :timestamp, :null => false

      # User/actor
      # maybe can take an agent uri - what about non-agents?
      String :actor, :null => false

      # Affected record(s) identifiers (URIs)
      # a bunch of foreign key columns or one big string column for multiple uris or a little audit_uri table refing here

      # Activity type
      # presumably an enum
      Integer audit_activity_type_id, :null => false

      # Method of change (bulk spreadsheet, API, rapid data entry, etc.)
      # another enum
      Integer audit_change_method_id, :null => false

      # need these?
      apply_mtime_columns
      Integer :lock_version, :default => 0, :null => false
    end
  end
end

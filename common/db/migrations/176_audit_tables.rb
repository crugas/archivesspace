require_relative 'utils'

Sequel.migration do
  up do
    create_table(:audit_event) do
      # From the spec:
      #   Timestamp
      #   User/actor
      #   Affected record(s) identifiers (URIs)
      #   Activity type
      #   Method of change (bulk spreadsheet, API, rapid data entry, etc.)

      primary_key :id

      # Timestamp
      DateTime :timestamp, :null => false

      # User/actor
      # maybe can take an agent uri - what about non-agents?
      String :actor, :null => false

      # Affected record(s) identifiers (URIs)
      # maybe a rlshp like with events

      DynamicEnum audit_activity_type_id, :null => false
      DynamicEnum audit_change_method_id, :null => false

      # need these?
      apply_mtime_columns
      Integer :lock_version, :default => 0, :null => false
    end

    create_editable_enum("audit_activity_type", ["create", "edit", "delete", "merge", "transfer", "publish", "unpublish", "other"])
    create_editable_enum("audit_change_method", ["form", "api", "bulk", "rapid", "system", "other"])

    create_table(:audit_event_rlshp) do
      primary_key :id

      Integer :audit_event_id

      Integer :accession_id
      Integer :resource_id
      Integer :archival_object_id
      Integer :digital_object_id
      Integer :digital_object_component_id
      Integer :agent_person_id
      Integer :agent_family_id
      Integer :agent_corporate_entity_id
      Integer :agent_software_id
      Integer :aspace_relationship_position

      apply_mtime_columns(false)
    end

    alter_table(:audit_event_rlshp) do
      add_foreign_key([:audit_event_id], :audit_event, :key => :id)
      add_foreign_key([:accession_id], :accession, :key => :id)
      add_foreign_key([:resource_id], :resource, :key => :id)
      add_foreign_key([:archival_object_id], :archival_object, :key => :id)
      add_foreign_key([:digital_object_id], :digital_object, :key => :id)
      add_foreign_key([:agent_person_id], :agent_person, :key => :id)
      add_foreign_key([:agent_family_id], :agent_family, :key => :id)
      add_foreign_key([:agent_corporate_entity_id], :agent_corporate_entity, :key => :id)
      add_foreign_key([:agent_software_id], :agent_software, :key => :id)
    end
  end
end

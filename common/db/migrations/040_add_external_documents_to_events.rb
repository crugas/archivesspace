Sequel.migration do
  no_audit_events_required!

  up do
    alter_table(:external_document) do
      add_column( :event_id, :integer, :null => true )
      add_foreign_key([:event_id], :event, :key => :id, :name => 'event_external_document_fk')
    end
  end

end

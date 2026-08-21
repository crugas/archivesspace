# frozen_string_literal: true

require_relative 'utils'

Sequel.migration do
  no_audit_events_required!

  up do
    self[:collection_management].update(system_mtime: Time.now)
  end

  down do
  end
end

require_relative 'utils'

Sequel.migration do
  no_audit_events_required!

  up do
    $stderr.puts("Change file_size_bytes from int to bigint")
    alter_table(:file_version) do
      set_column_type(:file_size_bytes, 'bigint')
    end
  end

end

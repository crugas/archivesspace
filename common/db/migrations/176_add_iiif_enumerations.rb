require_relative 'utils'

Sequel.migration do
  up do
    enum_id = self[:enumeration]
                .filter(:name => 'file_version_file_format_name')
                .get(:id)

    next_position = self[:enumeration_value]
                      .filter(:enumeration_id => enum_id)
                      .max(:position) + 1

    enum_exists = self[:enumeration_value]
                    .filter(:enumeration_id => enum_id,
                            :value => 'iiif')
                    .count == 1

    unless enum_exists
      self[:enumeration_value]
        .insert(:enumeration_id => enum_id,
                :value => 'iiif',
                :position => next_position)
      end
  end
end

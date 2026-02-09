module Thumbnails
  def self.included(base)
    base.extend(ClassMethods)
  end

  ThumbnailCandidate =
    Struct.new(:instance_is_representative,
               :digital_object_title,
               :file_version_file_uri,
               :file_version_use_statement,
               :file_version_file_format_name,
               :file_version_xlink_show_attribute,
               :file_version_is_representative,
               :file_version_is_display_thumbnail,
               :file_version_caption)

  module ClassMethods
    def fetch_thumbnail_candidates(objs)
      candidates = {}

      candidate_query =
        if self.included_modules.include?(FileVersions)
          # Digital Object and Digital Object Components
          self
            .join(:file_version, Sequel.qualify(:file_version, :"#{self.table_name}_id") => Sequel.qualify(self.table_name, :id))
            .filter(Sequel.qualify(self.table_name, :id) => objs.map(&:id))
            .filter(Sequel.qualify(:file_version, :publish) => 1)
            .order(Sequel.qualify(:file_version, :id))
            .select(
              Sequel.as(Sequel.qualify(self.table_name, :id), :record_id),
              Sequel.as(Sequel.qualify(self.table_name, :title), :digital_object_title),
              Sequel.as(Sequel.qualify(:file_version, :file_uri), :file_version_file_uri),
              Sequel.as(Sequel.qualify(:file_version, :use_statement_id), :file_version_use_statement_id),
              Sequel.as(Sequel.qualify(:file_version, :file_format_name_id), :file_version_file_format_name_id),
              Sequel.as(Sequel.qualify(:file_version, :is_representative), :file_version_is_representative),
              Sequel.as(Sequel.qualify(:file_version, :is_display_thumbnail), :file_version_is_display_thumbnail),
              Sequel.as(Sequel.qualify(:file_version, :caption), :file_version_caption),
              Sequel.as(Sequel.qualify(:file_version, :xlink_show_attribute_id), :file_version_xlink_show_attribute_id))

        elsif self.name == 'FileVersion'
          FileVersion
            .filter(Sequel.qualify(:file_version, :id) => objs.map(&:id))
            .order(Sequel.qualify(:file_version, :id))
            .select(
              Sequel.as(Sequel.qualify(:file_version, :id), :record_id),
              Sequel.as(Sequel.qualify(:file_version, :file_uri), :file_version_file_uri),
              Sequel.as(Sequel.qualify(:file_version, :use_statement_id), :file_version_use_statement_id),
              Sequel.as(Sequel.qualify(:file_version, :file_format_name_id), :file_version_file_format_name_id),
              Sequel.as(Sequel.qualify(:file_version, :is_representative), :file_version_is_representative),
              Sequel.as(Sequel.qualify(:file_version, :is_display_thumbnail), :file_version_is_display_thumbnail),
              Sequel.as(Sequel.qualify(:file_version, :caption), :file_version_caption),
              Sequel.as(Sequel.qualify(:file_version, :xlink_show_attribute_id), :file_version_xlink_show_attribute_id))

        elsif self.included_modules.include?(Instances)
          instance_fk_col = :"#{self.table_name}_id"

          Instance
            .join(:instance_do_link_rlshp, Sequel.qualify(:instance_do_link_rlshp, :instance_id) => Sequel.qualify(:instance, :id))
            .join(:digital_object, Sequel.qualify(:digital_object, :id) => Sequel.qualify(:instance_do_link_rlshp, :digital_object_id))
            .join(:file_version, Sequel.qualify(:file_version, :digital_object_id) => Sequel.qualify(:digital_object, :id))
            .filter(Sequel.qualify(:instance, instance_fk_col) => objs.map(&:id))
            .filter(Sequel.qualify(:digital_object, :publish) => 1)
            .filter(Sequel.~(Sequel.qualify(:digital_object, :suppressed) => 1))
            .filter(Sequel.qualify(:file_version, :publish) => 1)
            .order(Sequel.qualify(:file_version, :id))
            .select(
              Sequel.as(Sequel.qualify(:instance, instance_fk_col), :record_id),
              Sequel.as(Sequel.qualify(:instance, :is_representative), :instance_is_representative),
              Sequel.as(Sequel.qualify(:digital_object, :title), :digital_object_title),
              Sequel.as(Sequel.qualify(:file_version, :file_uri), :file_version_file_uri),
              Sequel.as(Sequel.qualify(:file_version, :use_statement_id), :file_version_use_statement_id),
              Sequel.as(Sequel.qualify(:file_version, :file_format_name_id), :file_version_file_format_name_id),
              Sequel.as(Sequel.qualify(:file_version, :is_representative), :file_version_is_representative),
              Sequel.as(Sequel.qualify(:file_version, :is_display_thumbnail), :file_version_is_display_thumbnail),
              Sequel.as(Sequel.qualify(:file_version, :caption), :file_version_caption),
              Sequel.as(Sequel.qualify(:file_version, :xlink_show_attribute_id), :file_version_xlink_show_attribute_id))

        else
          raise "Record type does not support thumbnails: #{self.name}"
        end

      candidate_query.each do |row|
        candidates[row[:record_id]] ||= []
        candidates[row[:record_id]] << ThumbnailCandidate.new(
          row[:instance_is_representative] == 1,
          row[:digital_object_title],
          row[:file_version_file_uri],
          BackendEnumSource.value_for_id('file_version_use_statement', row[:file_version_use_statement_id]),
          BackendEnumSource.value_for_id('file_version_file_format_name', row[:file_version_file_format_name_id]),
          BackendEnumSource.value_for_id('file_version_xlink_show_attribute', row[:file_version_xlink_show_attribute_id]),
          row[:file_version_is_representative] == 1,
          row[:file_version_is_display_thumbnail] == 1,
          row[:file_version_caption])
      end

      candidates
    end

    def find_representative_candidate(thumbnail_candidates)
      thumbnail_candidates.detect{|candidate| candidate.file_version_is_representative}
    end

    def find_representative_instance_candidates(thumbnail_candidates)
      thumbnail_candidates.filter{|candidate| candidate.instance_is_representative}
    end

    def find_preferred_thumbnail_candidate(thumbnail_candidates)
      # If an instance is marked as representative, prefer its file versions; otherwise, pool all linked DOs.
      blessed_candidates =
        if (representative_candidates = find_representative_instance_candidates(thumbnail_candidates)).length > 0
          representative_candidates
        else
          thumbnail_candidates
        end

      # If present, use `is_display_thumbnail` flag to explicitly designate a file version as the thumbnail.
      preferred_candidate = blessed_candidates.detect{|candidate| candidate.file_version_is_display_thumbnail}

      # If none, prefer a file with `use_statement=image-thumbnail`.
      preferred_candidate ||= blessed_candidates.detect{|candidate| candidate.file_version_use_statement == 'image-thumbnail'}

      # If none, prefer a representative file version if it is an allowed image type.
      preferred_candidate ||= blessed_candidates.detect{|candidate| is_candidate_as_image?(candidate)}

      # If none, fall back to the first available file version.
      # FIXME Nah?
      # preferred_candidate ||= blessed_candidates.detect{|candidate| is_candidate_as_image?(candidate)}

      preferred_candidate
    end

    def calculate_image_url(thumbnail_candidates)
      preferred_candidate = find_preferred_thumbnail_candidate(thumbnail_candidates)

      if preferred_candidate
        preferred_candidate.file_version_file_uri
      else
        nil
      end
    end

    def calculate_best_representation_candidate(thumbnail_candidates)
      # If an instance is marked as representative, prefer its file versions; otherwise, pool all linked DOs.
      blessed_candidates =
        if (representative_candidates = find_representative_instance_candidates(thumbnail_candidates)).length > 0
          representative_candidates
        else
          thumbnail_candidates
        end

      # Prefer the representative file version
      best_candidate = blessed_candidates.detect{|candidate| candidate.file_version_is_representative}

      # If none, prefer the first non-thumbnail/embed file version.
      best_candidate ||= blessed_candidates.detect{|candidate| candidate.file_version_use_statement != 'image-thumbnail' && candidate.file_version_xlink_show_attribute != 'embed'}

      # If none, fall back to is_display_thumbnail
      best_candidate ||= blessed_candidates.detect{|candidate| candidate.file_version_is_display_thumbnail}

      # If none, fall back to the first available.
      best_candidate ||= blessed_candidates.first

      best_candidate
    end

    def calculate_link_url(thumbnail_candidates)
      if (thumbnail_candidate = calculate_best_representation_candidate(thumbnail_candidates))
        thumbnail_candidate.file_version_file_uri
      end
    end

    def calculate_caption(record_json, thumbnail_candidates)
      # If an instance is marked as representative, prefer its file versions; otherwise, pool all linked DOs.
      blessed_candidates =
        if (representative_candidates = find_representative_instance_candidates(thumbnail_candidates)).length > 0
          representative_candidates
        else
          thumbnail_candidates
        end

      # Prefer the representative’s caption.
      caption_text =
        if (representative_with_caption = blessed_candidates.detect{|candidate| candidate.file_version_is_representative && candidate.file_version_caption})
          representative_with_caption.file_version_caption
        end

      # If absent, use the representative’s Digital Object title.
      caption_text ||=
        if (representative_candidate = blessed_candidates.detect{|candidate| candidate.file_version_is_representative})
          representative_candidate.digital_object_title
        end

      # If absent, use the thumbnail caption.
      thumbnail_candidate = find_preferred_thumbnail_candidate(thumbnail_candidates)
      caption_text ||=
        if thumbnail_candidate
          thumbnail_candidate.file_version_caption
        end

      # If absent, use the thumbnail’s Digital Object title.
      caption_text ||=
        if thumbnail_candidate
          thumbnail_candidate.digital_object_title
        end

      # If absent, use the first DO’s title.
      caption_text ||=
        if thumbnail_candidates.first
          thumbnail_candidates.first.digital_object_title
        end

      # If absent, fall back to the record display string.
      caption_text ||= record_json['display_string'] || record_json['title']

      caption_text
    end

    def is_candidate_as_image?(candidate)
      begin
        uri = URI(candidate.file_version_file_uri)
        if AppConfig[:thumbnail_file_format_names].include?(candidate.file_version_file_format_name) && ['http', 'https'].include?(uri.scheme)
          true
        else
          false
        end
      rescue
        false
      end
    end

    def find_a_thumbnail(record_json, thumbnail_candidates)
      if thumbnail_candidates.empty?
        return nil
      end

      image_url = calculate_image_url(thumbnail_candidates)
      link_url = calculate_link_url(thumbnail_candidates)

      if image_url || link_url
        {
          'image_url' => image_url, # placeholder will show if image_url is null
          'link_url' => link_url,
          'caption' => calculate_caption(record_json, thumbnail_candidates),
        }
      else
        nil
      end
    end

    def sequel_to_jsonmodel(objs, opts = {})
      jsons = super
      thumbnail_candidates_map = fetch_thumbnail_candidates(objs)

      jsons.zip(objs).each do |json, obj|
        json['thumbnail'] = find_a_thumbnail(json, thumbnail_candidates_map.fetch(obj.id, []))
      end

      jsons
    end
  end
end
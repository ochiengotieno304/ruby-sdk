# frozen_string_literal: true

module Elarian
  module Utils
    GP = Google::Protobuf

    class << self
      def parse_string_or_byte_val(value)
        string_val = value[:string_val]
        return value[:bytes_val] if string_val.empty?

        try_parsing_as_json(string_val)
      end

      def try_parsing_as_json(value)
        JSON.parse(value)
      rescue JSON::ParserError
        value
      end

      def get_enum_value(target, key, prefix)
        target.const_get("#{prefix}_#{key}".upcase, false)
      rescue NameError
        raise ArgumentError, "Invalid key #{key.inspect}. Valid keys are #{valid_enum_keys(target, prefix)}"
      end

      def get_enum_string(target, value, prefix)
        begin
          target.const_get(value, false)
        rescue NameError
          raise "invalid enum value #{value} for #{target}"
        end

        value.to_s.gsub("#{prefix}_", "")
      end

      def valid_enum_keys(target, prefix)
        target.constants
              .map { |c| c.to_s.split("#{prefix}_").last.to_sym }
              .reject { |c| %i[UNSPECIFIED UNKNOWN].include?(c) }
      end

      def assert_keys_present(hash, required_keys, hash_name = "Hash")
        assert_type(hash, hash_name, Hash)
        required_keys.each do |key|
          unless hash.key?(key)
            raise ArgumentError, "#{hash_name} missing one or more required keys. Required keys are: #{required_keys}"
          end
        end
      end

      def assert_only_valid_keys_present(hash, hash_name, valid_keys)
        hash.each_key do |key|
          unless valid_keys.include? key
            raise ArgumentError, "Invalid #{hash_name} property #{key}. Valid keys are: #{valid_keys}"
          end
        end
      end

      def assert_type(object, object_name, expected_type)
        return if object.is_a? expected_type

        raise ArgumentError, "Invalid #{object_name} type. Expected #{expected_type} got #{object.class}"
      end

      # @param pb_timestamp [Hash] the <seconds, nanoseconds> tuple representing the protobuf timestamp
      def pb_to_time(pb_timestamp)
        GP::Timestamp.new(pb_timestamp).to_time.utc
      end

      def pb_duration_seconds(pb_duration)
        GP::Duration.new(pb_duration).to_f
      end
    end
  end
end

# frozen_string_literal: true

require "json"

module Elarian
  module Utils
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

      def valid_enum_keys(target, prefix)
        target.constants.reject { |c| c == :UNSPECIFIED || c == :UNKNOWN }
          .map { |c| c.to_s.split("#{prefix}_").last.to_sym }
      end

      def assert_keys_present(hash, required_keys, hash_name = "Hash")
        assert_type(hash, hash_name, Hash)
        required_keys.each do |key|
          unless hash.key?(key)
            raise ArgumentError, "#{hash_name} missing one or more required keys. Required keys are: #{required_keys}"
          end
        end
      end

      def assert_type(object, object_name, expected_type)
        unless object.is_a? expected_type
          raise ArgumentError, "Invalid #{object_name} type. Expected #{expected_type} got #{object.class}"
        end
      end

      def get_enum_value(target, key, prefix)
        begin
          return target.const_get("#{prefix}_#{key}".upcase, false)
        rescue NameError
          raise "Invalid key #{key.inspect}"
        end
      end

      def assert_keys_present(hash, required_keys, hash_name='Hash')
        assert_type(hash, hash_name, Hash)
        required_keys.each do |key|
          unless hash.key?(key)
            raise ArgumentError, "#{hash_name} missing one or more required keys. Required keys are: #{required_keys}"
          end
        end
      end

      def assert_type(object, object_name, expected_type)
        unless object.is_a? expected_type
          raise ArgumentError, "Invalid #{object_name} type. Expected #{expected_type} got #{object.class}"
        end
      end
    end
  end
end

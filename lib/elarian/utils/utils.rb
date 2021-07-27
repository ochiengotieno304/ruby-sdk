# frozen_string_literal: true

module Elarian
  module Utils # rubocop:disable Metrics/ModuleLength
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
        assert_type(hash, hash_name, Hash)
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

      # @param pb_timestamp [Hash] the <seconds, nanos> tuple representing the protobuf timestamp
      def pb_to_time(pb_timestamp)
        micros = pb_timestamp[:nanos] / 1e3
        Time.at(pb_timestamp[:seconds], micros)
      end

      def pb_duration_seconds(pb_duration)
        pb_duration[:seconds] + pb_duration[:nanos] / 1e9
      end

      def map_purse_counter_party(purse)
        P::PaymentPurseCounterParty.new(purse_id: purse[:purse_id])
      end

      def map_customer_counter_party(customer)
        partition, number, provider = customer[:customer_number].values_at(:partition, :number, :provider)
        partition = { value: partition } unless partition.nil?
        customer_number = P::CustomerNumber.new(
          number: number,
          provider: get_enum_value(P::CustomerNumberProvider, provider, "CUSTOMER_NUMBER_PROVIDER"),
          partition: partition
        )
        channel_number = P::PaymentChannelNumber.new(
          number: customer[:channel_number][:number],
          channel: get_enum_value(P::PaymentChannel, customer[:channel_number][:channel], "PAYMENT_CHANNEL")
        )
        P::PaymentCustomerCounterParty.new(customer_number: customer_number, channel_number: channel_number)
      end

      def map_wallet_counter_party(wallet)
        P::PaymentWalletCounterParty.new(
          wallet_id: wallet[:wallet_id], customer_id: wallet[:customer_id]
        )
      end

      def map_channel_counter_party(channel)
        channel_number = P::PaymentChannelNumber.new(
          number: channel[:channel_number][:number],
          channel: get_enum_value(P::PaymentChannel, channel[:channel_number][:channel], "PAYMENT_CHANNEL")
        )
        P::PaymentChannelCounterParty.new(
          channel_number: channel_number,
          channel_code: channel[:network_code],
          account: { value: channel[:account] }
        )
      end

      def map_payment_counter_party(party)
        purse = map_purse_counter_party(party[:purse]) if party.key?(:purse)
        customer = map_customer_counter_party(party[:customer]) if party.key?(:customer)
        wallet = map_wallet_counter_party(party[:wallet]) if party.key?(:wallet)
        channel = map_channel_counter_party(party[:channel]) if party.key?(:channel)
        P::PaymentCounterParty.new(
          purse: purse,
          customer: customer,
          wallet: wallet,
          channel: channel
        )
      end
    end
  end
end

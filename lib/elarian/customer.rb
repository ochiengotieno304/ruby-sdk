# frozen_string_literal: true

module Elarian
  class Customer
    include Utils::AppToServerCommandsHelper

    attr_reader :client

    def initialize(client:, id: nil, number: nil, provider: nil)
      @client = client
      @id = id
      @number = number
      @provider = provider

      validate
    end

    def get_state
      command = P::GetCustomerStateCommand.new(id_or_number)
      send_command(:get_customer_state, command)
    end

    # @param tags [Array]
    def update_tags(tags)
      Utils.assert_type(tags, "tags", Array)

      updates = tags.map do |tag|
        mapping = P::IndexMapping.new(key: tag[:key], value: { value: tag[:value] })
        P::CustomerIndex.new(mapping: mapping, expires_at: tag[:expires_at])
      end
      command = P::UpdateCustomerTagCommand.new(**id_or_number, updates: updates)
      send_command(:update_customer_tag, command)
    end

    # @param keys [Array]
    def delete_tags(keys)
      Utils.assert_type(keys, "keys", Array)

      command = P::DeleteCustomerTagCommand.new(**id_or_number, deletions: keys)
      send_command(:delete_customer_tag, command)
    end

    def get_tags
      get_state.map do |get_state_payload|
        get_state_payload.dig(:data, :identity_state, :tags)
      end
    end

    # @param reminder [Hash]
    def add_reminder(reminder)
      Utils.assert_type(reminder, "reminder", Hash)
      Utils.assert_only_valid_keys_present(reminder, "reminder", %i[key remind_at interval payload])

      # NOTE: the protobuf interface suggests that "key" and "remind_at" are optional.
      # But requests fail without these values. So let's force users to provide them.
      if !reminder[:key] || !reminder[:remind_at]
        raise ArgumentError, "Either :key or :remind_at is missing in reminder"
      end

      payload = { value: reminder[:payload] }
      customer_reminder = P::CustomerReminder.new(reminder.merge(payload: payload))
      command = P::AddCustomerReminderCommand.new(**id_or_number, reminder: customer_reminder)
      send_command(:add_customer_reminder, command)
    end

    def cancel_reminder(key)
      command = P::CancelCustomerReminderCommand.new(**id_or_number, key: key)
      send_command(:cancel_customer_reminder, command)
    end

    def get_secondary_ids
      get_state.map do |get_state_resp|
        get_state_resp.dig(:data, :identity_state, :secondary_ids)
      end
    end

    def update_secondary_ids(secondary_ids)
      updates = secondary_ids.map do |id|
        raise ArgumentError, "Invalid secondary id #{id}. Missing :key and/or :value" unless id[:key] && id[:value]

        mapping = P::IndexMapping.new(key: id[:key], value: { value: id[:value] })
        P::CustomerIndex.new(mapping: mapping, expires_at: id[:expires_at])
      end

      command = P::UpdateCustomerSecondaryIdCommand.new(**id_or_number, updates: updates)
      send_command(:update_customer_secondary_id, command)
    end

    def delete_secondary_ids(secondary_ids)
      deletions = secondary_ids.map do |id|
        raise ArgumentError, "Invalid secondary id #{id}. Missing :key and/or :value" unless id[:key] && id[:value]

        P::IndexMapping.new(key: id[:key], value: { value: id[:value] })
      end

      command = P::DeleteCustomerSecondaryIdCommand.new(**id_or_number, deletions: deletions)
      send_command(:delete_customer_secondary_id, command)
    end

    def get_metadata
      get_state.map do |get_state_resp|
        metadata = get_state_resp.dig(:data, :identity_state, :metadata)
        if metadata
          metadata.transform_values { |val| Utils.parse_string_or_byte_val(val) }
        else
          metadata
        end
      end
    end

    def update_metadata(data)
      command = P::UpdateCustomerMetadataCommand.new(**id_or_number)
      data.map do |key, val|
        command.updates[key] = P::DataMapValue.new(string_val: JSON.dump(val))
      end
      send_command(:update_customer_metadata, command)
    end

    def delete_metadata(keys)
      Utils.assert_type(keys, "keys", Array)

      command = P::DeleteCustomerMetadataCommand.new(**id_or_number, deletions: keys)
      send_command(:delete_customer_metadata, command)
    end

    def update_app_data(data)
      update = P::DataMapValue.new(string_val: JSON.dump(data))
      command = P::UpdateCustomerAppDataCommand.new(**id_or_number, update: update)
      send_command(:update_customer_app_data, command)
    end

    def delete_app_data
      command = P::DeleteCustomerAppDataCommand.new(**id_or_number)
      send_command(:delete_customer_app_data, command)
    end

    def lease_app_data
      command = P::LeaseCustomerAppDataCommand.new(**id_or_number)
      send_command(:lease_customer_app_data, command).map do |payload|
        # TODO: Even if this is a special case, can't we just do in in ResponseParser ?
        payload[:value] = Utils.parse_string_or_byte_val(payload[:value]) if payload[:value]
        payload
      end
    end

    def update_activity(activity_channel, activity)
      raise "Customer number not set" unless @number

      Utils.assert_keys_present(activity_channel, %i[number channel], "activity_channel")
      Utils.assert_keys_present(activity, %i[session_id key], "activity")

      channel = Utils.get_enum_value(
        P::ActivityChannel, activity_channel.fetch(:channel, "UNSPECIFIED"), "ACTIVITY_CHANNEL"
      )
      command = P::CustomerActivityCommand.new(
        customer_number: customer_number,
        channel_number: P::ActivityChannelNumber.new(number: activity_channel[:number], channel: channel),
        key: activity[:key],
        session_id: activity[:session_id]
      )
      # TODO: logic copy-pasted from Python-SDK, confirm that this is what we want.
      # Would be more logical to set each property one by one.
      command.properties["property"] = activity[:properties].to_s
      send_command(:customer_activity, command)
    end

    def send_message(messaging_channel, message)
      raise "Customer number not set" unless @number

      channel = Utils.get_enum_value(
        P::MessagingChannel, messaging_channel.fetch(:channel, "UNSPECIFIED"), "MESSAGING_CHANNEL"
      )
      command = P::SendMessageCommand.new(
        customer_number: customer_number,
        channel_number: P::MessagingChannelNumber.new(number: messaging_channel[:number], channel: channel),
        message: Utils::OutgoingMessageSerializer.serialize(message)
      )
      send_command(:send_message, command).map do |res|
        res.merge(status: Utils.get_enum_string(P::MessageDeliveryStatus, res[:status], "MESSAGE_DELIVERY_STATUS"))
      end
    end

    # @param other_customer [Hash]
    def adopt_state(other_customer)
      Utils.assert_type(other_customer, "other_customer", Hash)
      raise "Customer id not set" unless @id

      command = P::AdoptCustomerStateCommand.new(customer_id: @id)
      if other_customer.key?(:customer_id)
        command.other_customer_id = other_customer[:customer_id]
      elsif other_customer.key?(:number)
        provider = Utils.get_enum_value(
          P::CustomerNumberProvider, other_customer.fetch(:provider, "CELLULAR"), "CUSTOMER_NUMBER_PROVIDER"
        )
        other_cust_no = P::CustomerNumber.new(number: other_customer[:number], provider: provider)
        command.other_customer_number = other_cust_no
      else
        raise "Missing Other Customer id or number"
      end
      send_command(:adopt_customer_state, command)
    end

    # @param messaging_channel [Hash]
    # @param action [String]
    def update_messaging_consent(messaging_channel, action = "ALLOW")
      Utils.assert_type(messaging_channel, "messaging_channel", Hash)
      raise "Missing Customer Number" unless @number

      Utils.assert_keys_present(messaging_channel, %i[number channel], "messaging_channel")

      channel = Utils.get_enum_value(
        P::MessagingChannel, messaging_channel.fetch(:channel, "UNSPECIFIED"), "MESSAGING_CHANNEL"
      )
      command = P::UpdateMessagingConsentCommand.new(
        customer_number: customer_number,
        channel_number: P::MessagingChannelNumber.new(number: messaging_channel[:number], channel: channel),
        update: Utils.get_enum_value(
          P::MessagingConsentUpdate, action, "MESSAGING_CONSENT_UPDATE"
        )
      )
      send_command(:update_messaging_consent, command)
    end

    def reply_to_message(message_id, message)
      raise "customer_id not set" unless @id

      command = P::ReplyToMessageCommand.new(
        customer_id: @id,
        message_id: message_id,
        message: Utils::OutgoingMessageSerializer.serialize(message)
      )
      send_command(:reply_to_message, command).map do |res|
        res.merge(status: Utils.get_enum_string(P::MessageDeliveryStatus, res[:status], "MESSAGE_DELIVERY_STATUS"))
      end
    end

    private

    def validate
      raise ArgumentError, "Invalid client" unless @client.is_a? Client
      raise ArgumentError, "id or number must be provided" unless @id || @number
      return if valid_provider?

      raise ArgumentError, "Unrecognized provider (#{@provider}). Valid providers are: #{valid_providers}"
    end

    def valid_provider?
      @provider.nil? || valid_providers.include?(@provider.to_s.upcase)
    end

    def valid_providers
      providers = P::CustomerNumberProvider.constants.map do |value|
        value.to_s.split("CUSTOMER_NUMBER_PROVIDER_")[1]
      end
      providers.reject { |value| value == "UNSPECIFIED" }
    end

    def provider_symbol
      "CUSTOMER_NUMBER_PROVIDER_#{@provider}".upcase.to_sym if @provider
    end

    def id_or_number
      return { customer_id: @id } if @id

      { customer_number: customer_number }
    end

    def customer_number
      @customer_number ||= P::CustomerNumber.new(number: @number, provider: provider_symbol)
    end
  end
end

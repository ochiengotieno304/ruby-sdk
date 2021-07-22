# frozen_string_literal: true

module Elarian
  GP = Google::Protobuf

  class Customer
    def initialize(client:, id: nil, number: nil, provider: nil)
      @client = client
      @id = id
      @number = number
      @provider = provider

      validate
    end

    def get_state
      command = P::GetCustomerStateCommand.new(id_or_number)
      req = P::AppToServerCommand.new(get_customer_state: command)
      res = @client.send_command(req)
      parse_response(res)
    end

    # @param tags [Array]
    def update_tags(tags)
      raise ArgumentError, "Expected tags to be an Array. Got #{tags.class}" unless tags.is_a?(Array)

      command = P::UpdateCustomerTagCommand.new(id_or_number)
      tags.each do |tag|
        mapping = P::IndexMapping.new(
          key: tag[:key],
          value: GP::StringValue.new(value: tag[:value])
        )
        expires_at = GP::Timestamp.new(seconds: tag[:expires_at]) if tag.key?(:expires_at)
        index = P::CustomerIndex.new(mapping: mapping, expires_at: expires_at)
        command.updates.push index
      end
      req = P::AppToServerCommand.new(update_customer_tag: command)
      res = @client.send_command(req)
      parse_response(res)
    end

    # @param keys [Array]
    def delete_tags(keys)
      raise ArgumentError, "Expected keys to be an Array. Got #{keys.class}" unless keys.is_a?(Array)

      command = P::DeleteCustomerTagCommand.new(**id_or_number, deletions: keys)
      req = P::AppToServerCommand.new(delete_customer_tag: command)
      res = @client.send_command(req)
      parse_response(res)
    end

    def get_tags
      get_state.map do |get_state_payload|
        get_state_payload.dig(:data, :identity_state, :tags)
      end
    end

    # @param reminder [Hash]
    def add_reminder(reminder)
      raise ArgumentError, "Expected reminder to be a Hash. Got #{reminder.class}" unless reminder.is_a? Hash

      valid_keys = %i[key remind_at interval payload]
      reminder.keys.each do |key|
        unless valid_keys.include? key
          raise ArgumentError, "Invalid reminder property #{key}. Valid keys are: #{valid_keys}"
        end
      end

      # NOTE: the protobuf interface suggests that "key" and "remind_at" are optional.
      # But requests fail without these values.. and they fail in such a way that we get back an
      # RSocket frame that the library does not know how to handle...
      # So let's force users to provide these for now.
      if !reminder[:key] || !reminder[:remind_at]
        raise ArgumentError, "Either :key or :remind_at is missing in reminder"
      end

      payload = GP::StringValue.new(value: reminder[:payload])
      customer_reminder = P::CustomerReminder.new(reminder.merge(payload: payload))
      command = P::AddCustomerReminderCommand.new(**id_or_number, reminder: customer_reminder)
      req = P::AppToServerCommand.new(add_customer_reminder: command)
      res = @client.send_command(req)
      parse_response(res)
    end

    def cancel_reminder(key)
      command = P::CancelCustomerReminderCommand.new(**id_or_number, key: key)

      req = P::AppToServerCommand.new(cancel_customer_reminder: command)
      res = @client.send_command(req)
      parse_response(res)
    end

    def get_secondary_ids
      get_state.map do |get_state_resp|
        get_state_resp.dig(:data, :identity_state, :secondary_ids)
      end
    end

    def update_secondary_ids(secondary_ids)
      updates = secondary_ids.map do |id|
        raise ArgumentError, "Invalid secondary id #{id}. Missing :key and/or :value" unless id[:key] && id[:value]

        mapping = P::IndexMapping.new(key: id[:key], value: GP::StringValue.new(value: id[:value]))
        P::CustomerIndex.new(mapping: mapping, expires_at: id[:expires_at])
      end

      command = P::UpdateCustomerSecondaryIdCommand.new(**id_or_number, updates: updates)
      req = P::AppToServerCommand.new(update_customer_secondary_id: command)
      res = @client.send_command(req)
      parse_response(res)
    end

    def delete_secondary_ids(secondary_ids)
      deletions = secondary_ids.map do |id|
        raise ArgumentError, "Invalid secondary id #{id}. Missing :key and/or :value" unless id[:key] && id[:value]

        P::IndexMapping.new(key: id[:key], value: GP::StringValue.new(value: id[:value]))
      end

      command = P::DeleteCustomerSecondaryIdCommand.new(**id_or_number, deletions: deletions)
      req = P::AppToServerCommand.new(delete_customer_secondary_id: command)
      res = @client.send_command(req)
      parse_response(res)
    end

    def get_metadata
      get_state.map do |get_state_resp|
        metadata = get_state_resp.dig(:data, :identity_state, :metadata)
        if metadata
          Hash[metadata.map { |key, val| [key, Utils.parse_string_or_byte_val(val)] }]
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
      req = P::AppToServerCommand.new(update_customer_metadata: command)
      res = @client.send_command(req)
      parse_response(res)
    end

    def delete_metadata(keys)
      raise ArgumentError, "Expected keys to be an Array. Got #{keys.class}" unless keys.is_a?(Array)

      command = P::DeleteCustomerMetadataCommand.new(**id_or_number, deletions: keys)
      req = P::AppToServerCommand.new(delete_customer_metadata: command)
      res = @client.send_command(req)
      parse_response(res)
    end

    def update_app_data(data)
      update = P::DataMapValue.new(string_val: JSON.dump(data))
      command = P::UpdateCustomerAppDataCommand.new(**id_or_number, update: update)

      req = P::AppToServerCommand.new(update_customer_app_data: command)
      res = @client.send_command(req)
      parse_response(res)
    end

    def delete_app_data
      command = P::DeleteCustomerAppDataCommand.new(**id_or_number)
      req = P::AppToServerCommand.new(delete_customer_app_data: command)
      res = @client.send_command(req)
      parse_response(res)
    end

    def lease_app_data
      command = P::LeaseCustomerAppDataCommand.new(**id_or_number)
      req = P::AppToServerCommand.new(lease_customer_app_data: command)
      res = @client.send_command(req)
      parse_response(res).map do |payload|
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

      req = P::AppToServerCommand.new(customer_activity: command)
      res = @client.send_command(req)
      parse_response(res)
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

      req = P::AppToServerCommand.new(send_message: command)
      res = @client.send_command(req)
      parse_response(res)
    end

    # @param other_customer [Hash]
    def adopt_state(other_customer)
      unless other_customer.is_a? Hash
        raise ArgumentError, "Expected other customer to be a Hash. Got #{other_customer.class}"
      end
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

      req = P::AppToServerCommand.new(adopt_customer_state: command)
      res = @client.send_command(req)
      parse_response(res)
    end

    # @param messaging_channel [Hash]
    # @param action [String]
    def update_messaging_consent(messaging_channel, action = "ALLOW")
      unless messaging_channel.is_a? Hash
        raise ArgumentError, "Expected channel to be a Hash. Got #{messaging_channel.class}"
      end
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
      req = P::AppToServerCommand.new(update_messaging_consent: command)
      res = @client.send_command(req)
      parse_response(res)
    end

    def reply_to_message(message_id, message)
      raise "customer_id not set" unless @id

      command = P::ReplyToMessageCommand.new(
        customer_id: @id,
        message_id: message_id,
        message: Utils::OutgoingMessageSerializer.serialize(message)
      )

      req = P::AppToServerCommand.new(reply_to_message: command)
      res = @client.send_command(req)
      parse_response(res)
    end

    private

    def validate
      raise ArgumentError, "Invalid client" unless @client&.is_a? Elarian::Client
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

    def send_command(data)
      @client.send_command(data)
    end

    # Wraps the provided response subject, and returns a new response subject that emits a parsed response message
    #
    # @param response_subject [Rx::AsyncSubject] the original async response
    # @return [Rx::Observable] an observable which yields the server's parsed reply data or error message
    def parse_response(response_subject)
      response_subject.map do |payload|
        reply = ResponseParser.parse(payload)
        raise reply.error_message if reply.error?

        reply.data
      end
    end
  end
end

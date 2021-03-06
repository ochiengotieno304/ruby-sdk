# frozen_string_literal: true

module Elarian
  # Customer class that handles a single customer instance, must have one of customer_id or customer_number
  class Customer
    include Utils::AppToServerCommandsHelper

    # The connected Elarian client
    attr_reader :client

    # @param client The connected Elarian client
    # @param id The Elarian generated customer id
    # @param number The customer phone number
    # @param provider The customer phone number provider
    def initialize(client:, id: nil, number: nil, provider: nil)
      @client = client
      @id = id
      @number = number
      @provider = provider

      validate
    end

    # Returns a customer phone number
    # @return [Hash] A customer's phone number and provider
    def number
      as_hash = customer_number.to_h
      provider = Utils.get_enum_string(P::CustomerNumberProvider, as_hash[:provider], "CUSTOMER_NUMBER_PROVIDER")
      as_hash.merge(provider: provider)
    end

    # Gets a customer's current state
    # @return [Rx::Observable] The observable response
    def get_state
      command = P::GetCustomerStateCommand.new(id_or_number)
      send_command(:get_customer_state, command)
    end

    # Updates a customer's tags
    # @param tags [Array] Array of tags being updated
    # @return [Rx::Observable] The observable response
    def update_tags(tags)
      Utils.assert_type(tags, "tags", Array)

      updates = tags.map.with_index do |tag, idx|
        Utils.assert_keys_present(tag, %i[key value], "tags[#{idx}]")
        mapping = P::IndexMapping.new(key: tag[:key], value: { value: tag[:value] })
        P::CustomerIndex.new(mapping: mapping, expires_at: tag[:expires_at])
      end
      command = P::UpdateCustomerTagCommand.new(**id_or_number, updates: updates)
      send_command(:update_customer_tag, command)
    end

    # Deletes a customer's tags
    # @param keys [Array] Array of tags being deleted
    # @return [Rx::Observable] The observable response
    def delete_tags(keys)
      Utils.assert_type(keys, "keys", Array)
      keys.each.with_index { |key, idx| Utils.assert_type(key, "keys[#{idx}]", String) }

      command = P::DeleteCustomerTagCommand.new(**id_or_number, deletions: keys)
      send_command(:delete_customer_tag, command)
    end

    # Gets a customer's tags
    # @return [Rx::Observable] The observable response
    def get_tags
      get_state.map do |get_state_payload|
        get_state_payload.dig(:data, :identity_state, :tags)
      end
    end

    # Adds a reminder
    # @param reminder [Hash] Hash containing the details of the reminder
    # @return [Rx::Observable] The observable response
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

    # Cancels a reminder based on a key
    # @param key [String] Reminder key
    # @return [Rx::Observable] The observable response
    def cancel_reminder(key)
      Utils.assert_type(key, "key", String)
      command = P::CancelCustomerReminderCommand.new(**id_or_number, key: key)
      send_command(:cancel_customer_reminder, command)
    end

    # Gets the secondary ids of a customer
    # @return [Rx::Observable] The observable response
    def get_secondary_ids
      get_state.map do |get_state_resp|
        get_state_resp.dig(:data, :identity_state, :secondary_ids)
      end
    end

    # Updates a customer's secondary ids
    # @param secondary_ids [Array]  Array of secondary ids being updated
    # @return [Rx::Observable] The observable response
    def update_secondary_ids(secondary_ids)
      Utils.assert_type(secondary_ids, "secondary_ids", Array)
      updates = secondary_ids.map.with_index do |id, index|
        Utils.assert_keys_present(id, %i[key value], "secondary_ids[#{index}]")
        raise ArgumentError, "Invalid secondary id #{id}. Missing :key and/or :value" unless id[:key] && id[:value]

        mapping = P::IndexMapping.new(key: id[:key], value: { value: id[:value] })
        P::CustomerIndex.new(mapping: mapping, expires_at: id[:expires_at])
      end

      command = P::UpdateCustomerSecondaryIdCommand.new(**id_or_number, updates: updates)
      send_command(:update_customer_secondary_id, command)
    end

    # Deletes a customer's secondary ids
    # @param secondary_ids [Array] Array of secondary ids being deleted
    # @return [Rx::Observable] The observable response
    def delete_secondary_ids(secondary_ids)
      Utils.assert_type(secondary_ids, "secondary_ids", Array)
      deletions = secondary_ids.map.with_index do |id, index|
        Utils.assert_keys_present(id, %i[key value], "secondary_ids[#{index}]")

        P::IndexMapping.new(key: id[:key], value: { value: id[:value] })
      end

      command = P::DeleteCustomerSecondaryIdCommand.new(**id_or_number, deletions: deletions)
      send_command(:delete_customer_secondary_id, command)
    end

    # Gets the metadata of a customer
    # @return [Rx::Observable] The observable response
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

    # Updates a customer's metadata
    # @param data [Hash] Hash containing the metadata being updated
    # @return [Rx::Observable] The observable response
    def update_metadata(data)
      Utils.assert_type(data, "data", Hash)
      command = P::UpdateCustomerMetadataCommand.new(**id_or_number)
      data.map do |key, val|
        command.updates[key] = P::DataMapValue.new(string_val: JSON.dump(val))
      end
      send_command(:update_customer_metadata, command)
    end

    # Deletes a customer's metadata
    # @param keys [Array] Metadata keys being deleted
    # @return [Rx::Observable] The observable response
    def delete_metadata(keys)
      Utils.assert_type(keys, "keys", Array)

      command = P::DeleteCustomerMetadataCommand.new(**id_or_number, deletions: keys)
      send_command(:delete_customer_metadata, command)
    end

    # Updates a customer's app data
    # @param data [Hash] Hash containing the data being updated
    # @return [Rx::Observable] The observable response
    def update_app_data(data)
      Utils.assert_type(data, "data", Hash)
      update = P::DataMapValue.new(string_val: JSON.dump(data))
      command = P::UpdateCustomerAppDataCommand.new(**id_or_number, update: update)
      send_command(:update_customer_app_data, command)
    end

    # Deletes a customer's app data
    # @return [Rx::Observable] The observable response
    def delete_app_data
      command = P::DeleteCustomerAppDataCommand.new(**id_or_number)
      send_command(:delete_customer_app_data, command)
    end

    # Leases customer's app data
    # @return [Rx::Observable] The observable response
    def lease_app_data
      command = P::LeaseCustomerAppDataCommand.new(**id_or_number)
      send_command(:lease_customer_app_data, command).map do |payload|
        # TODO: Even if this is a special case, can't we just do in in ResponseParser ?
        payload[:value] = Utils.parse_string_or_byte_val(payload[:value]) if payload[:value]
        payload
      end
    end

    # Updates a customer's activity
    # @param activity_channel [Hash] Hash containing the activity channels
    # @param activity [Hash] Hash containing the activities
    # @return [Rx::Observable] The observable response
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
      command.properties["property"] = activity[:properties].to_s
      send_command(:customer_activity, command)
    end

    # Sends a message to a customer
    # @param messaging_channel [Hash] The messaging channel used
    # @param message [Hash] The message being sent
    # @return [Rx::Observable] The observable response
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

    # Adopts another customer's state
    # @param other_customer [Hash] Hash containing the other customer's details
    # @return [Rx::Observable] The observable response
    def adopt_state(other_customer)
      Utils.assert_type(other_customer, "other_customer", Hash)

      res = Rx::AsyncSubject.new
      retrieve_id.subscribe_on_completed do
        _adopt_state(other_customer)
          .as_observable
          .subscribe(
            ->(payload) { res.on_next(payload) },
            ->(err) { res.on_error(err) },
            -> { res.on_completed }
          )
      end

      res
    end

    # Updates a customer's engagement consent on this channel
    # @param messaging_channel [Hash] Hash containing the messaging channels
    # @param action [String] Choice of messaging consent.
    # @return [Rx::Observable] The observable response
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

    # Replies to a message from a customer
    # @param message_id [String] Specific message id being replied to
    # @param message [String] Message being sent back
    # @return [Rx::Observable] The observable response
    def reply_to_message(message_id, message)
      res = Rx::AsyncSubject.new

      retrieve_id.subscribe_on_completed do
        _reply_to_message(message_id, message)
          .as_observable
          .subscribe(
            ->(payload) { res.on_next(payload) },
            ->(err) { res.on_error(err) },
            -> { res.on_completed }
          )
      end

      res
    end

    private

    def _reply_to_message(message_id, message)
      command = P::ReplyToMessageCommand.new(
        customer_id: @id,
        message_id: message_id,
        message: Utils::OutgoingMessageSerializer.serialize(message)
      )
      send_command(:reply_to_message, command).map do |res|
        res.merge(status: Utils.get_enum_string(P::MessageDeliveryStatus, res[:status], "MESSAGE_DELIVERY_STATUS"))
      end
    end

    def _adopt_state(other_customer)
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

    def validate
      raise ArgumentError, "Invalid client" unless @client.is_a? BaseClient
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

    def retrieve_id
      return Rx::Observable.just(@id) if @id

      get_state.map { |state| @id = state.dig(:data, :customer_id) }.as_observable
    end
  end
end

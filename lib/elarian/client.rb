# frozen_string_literal: true

module Elarian
  # Elarian class that allows setting of handlers and reacting to various events
  class Client < BaseClient
    include Utils::AppToServerCommandsHelper

    # @param org_id The Organization id
    # @param app_id The app id generated from the dashboard
    # @param api_key The generated API key from the dashboard
    # @param options Extra options passed to the Elarian client
    def initialize(org_id:, app_id:, api_key:, options: {})
      events = %i[
        reminder
        messaging_session_started
        messaging_session_renewed
        messaging_session_ended
        messaging_consent_update
        received_sms
        received_fb_messenger
        received_telegram
        received_whatsapp
        received_email
        voice_call
        ussd_session
        message_status
        sent_message_reaction
        received_payment
        payment_status
        wallet_payment_status
        customer_activity
      ]
      super(org_id: org_id, app_id: app_id, api_key: api_key, options: options, events: events)
    end

    # Generate an auth token to use in place of API keys
    # @return [Rx::Observable] The observable response
    def generate_auth_token
      command = P::GenerateAuthTokenCommand.new
      send_command(:generate_auth_token, command)
    end

    # Set a reminder to be triggered at the specified time for customers with a particular tag
    # @param tag [Hash] A particular Tag associated with the customer
    # @param reminder [Hash] The Reminder to be added
    # @return [Rx::Observable] The observable response
    def add_customer_reminder_by_tag(tag, reminder)
      Utils.assert_keys_present(tag, %i[value key], "tag", strict: true)
      Utils.assert_only_valid_keys_present(reminder, "reminder", %i[key remind_at interval payload])
      Utils.assert_keys_present(reminder, %i[key remind_at], "reminder")

      payload = { value: reminder[:payload] }
      customer_reminder = P::CustomerReminder.new(reminder.merge(payload: payload))
      command = P::AddCustomerReminderTagCommand.new(
        tag: { key: tag[:key], value: { value: tag[:value] } },
        reminder: customer_reminder
      )
      send_command(:add_customer_reminder_tag, command)
    end

    # Cancels a a previously set reminder using a tag and key
    # @param tag [Hash] A particular Tag associated with the customer
    # @param key [Hash] The key of a reminder to be cancelled
    # @return [Rx::Observable] The observable response
    def cancel_customer_reminder_by_tag(key, tag)
      Utils.assert_type(key, "key", String)
      Utils.assert_type(tag, "tag", Hash)

      command = P::CancelCustomerReminderTagCommand.new(
        key: key,
        tag: { key: tag[:key], value: { value: tag[:value] } }
      )
      send_command(:cancel_customer_reminder_tag, command)
    end

    # Send a message to customers with a specific tag
    # @param tag [Hash] A particular Tag associated with the customer
    # @param messaging_channel [Hash] The messaging channel to be used
    # @param message [Hash] The message to be sent
    # @return [Rx::Observable] The observable response
    def send_message_by_tag(tag, messaging_channel, message)
      Utils.assert_type(tag, "tag", Hash)
      Utils.assert_keys_present(messaging_channel, %i[channel number], "messaging_channel")
      Utils.assert_keys_present(message, [:body], "message")

      channel = Utils.get_enum_value(
        P::MessagingChannel, messaging_channel.fetch(:channel, "UNSPECIFIED"), "MESSAGING_CHANNEL"
      )

      command = P::SendMessageTagCommand.new(
        channel_number: P::MessagingChannelNumber.new(number: messaging_channel[:number], channel: channel),
        tag: { key: tag[:key], value: { value: tag[:value] } },
        message: Utils::OutgoingMessageSerializer.serialize(message)
      )
      send_command(:send_message_tag, command)
    end

    # Initiate a payment transaction.
    # @param debit_party[Hash] Details of the customer the money is coming from
    # @param credit_party[Hash] Details of the customer the money is going to
    # @param value[Hash] Details of the Amount and Currency being sent
    # @return [Rx::Observable] The observable response
    def initiate_payment(debit_party:, credit_party:, value:)
      Utils.assert_type(debit_party, "debit_party", Hash)
      Utils.assert_type(credit_party, "credit_party", Hash)
      Utils.assert_keys_present(value, %i[amount currency_code], "value")

      value = P::Cash.new(amount: value[:amount], currency_code: value[:currency_code])
      command = P::InitiatePaymentCommand.new(
        value: value,
        debit_party: Utils.map_payment_counter_party(debit_party),
        credit_party: Utils.map_payment_counter_party(credit_party)
      )
      send_command(:initiate_payment, command).map do |res|
        res.merge(status: Utils.get_enum_string(P::PaymentStatus, res[:status], "PAYMENT_STATUS"))
      end
    end
  end
end

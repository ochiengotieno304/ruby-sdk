# frozen_string_literal: true

module Elarian
  class Elarian < Client
    include ::Elarian::AppToServerCommandsHelper

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

    def generate_auth_token
      command = P::GenerateAuthTokenCommand.new
      send_command(:generate_auth_token, command)
    end

    # @param tag [Hash]
    # @param reminder [Hash]
    def add_customer_reminder_by_tag(tag, reminder)
      Utils.assert_type(reminder, "reminder", Hash)
      Utils.assert_type(tag, "tag", Hash)
      Utils.assert_only_valid_keys_present(reminder, "reminder", %i[key remind_at interval payload])

      if !reminder[:key] || !reminder[:remind_at]
        raise ArgumentError, "Either :key or :remind_at is missing in reminder"
      end

      payload = { value: reminder[:payload] }
      customer_reminder = P::CustomerReminder.new(reminder.merge(payload: payload))
      command = P::AddCustomerReminderTagCommand.new(
        tag: { key: tag[:key], value: { value: tag[:value] } },
        reminder: customer_reminder
      )
      send_command(:add_customer_reminder_tag, command)
    end

    def cancel_customer_reminder_by_tag(key, tag)
      Utils.assert_type(key, "key", String)
      Utils.assert_type(tag, "tag", Hash)

      command = P::CancelCustomerReminderTagCommand.new(
        key: key,
        tag: { key: tag[:key], value: { value: tag[:value] } }
      )
      send_command(:cancel_customer_reminder_tag, command)
    end

    def send_message_by_tag(tag, messaging_channel, message)
      { tag: tag, messaging_channel: messaging_channel, message: message }.each do |name, value|
        Utils.assert_type(value, name, Hash)
      end

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

    # @param debit_party[Hash] The debit party
    # @param credit_party[Hash]
    # @param value[Hash]
    def initiate_payment(debit_party, credit_party, value)
      Utils.assert_type(debit_party, "debit_party", Hash)
      Utils.assert_type(credit_party, "credit_party", Hash)
      Utils.assert_type(value, "value", Hash)
      Utils.assert_keys_present(value, %i[amount currency_code], "value")

      value = P::Cash.new(amount: value[:amount], currency_code: value[:currency_code])
      command = P::InitiatePaymentCommand.new(
        value: value,
        debit_party: Utils.map_payment_counter_party(debit_party),
        credit_party: Utils.map_payment_counter_party(credit_party)
      )
      send_command(:initiate_payment, command)
    end

    private

    # Used by some helper methods included in this class
    def client
      self
    end
  end
end

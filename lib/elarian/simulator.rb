# frozen_string_literal: true

module Elarian
  # Client class that simulates a connection to the Elarian backend
  class Simulator < Client
    include Utils::AppToServerCommandsHelper

    # @param org_id The Organization id
    # @param app_id The app id generated from the dashboard
    # @param api_key The generated API key from the dashboard
    # @param options Extra options passed to the client
    def initialize(org_id:, app_id:, api_key:, options: {})
      events = %i[send_message make_voice_call send_customer_payment send_channel_payment checkout_payment]
      options = options.merge(is_simulator: true)

      super(org_id: org_id, app_id: app_id, api_key: api_key, options: options, events: events)
    end

    # Simulate sending a message.
    # @param phone_number [String] Phone number that sent the message
    # @param messaging_channel [Hash] Details of the messaging channel used
    # @param session_id [String] Session id of the simulation
    # @param message_parts [Array] Array of the message parts
    # @param cost [Hash] Details of the message cost amount and currency
    def receive_message(phone_number:, messaging_channel:, session_id:, message_parts:, cost: nil)
      Utils.assert_keys_present(cost, "cost", %i[currency_code amount], strict: true) unless cost.nil?
      Utils.assert_keys_present(messaging_channel, %i[channel number], "messaging_channel", strict: true)

      cost ||= { currency_code: "KES", amount: 0 }
      channel_enum = Utils.get_enum_value(P::MessagingChannel, messaging_channel[:channel], "MESSAGING_CHANNEL")
      command = P::ReceiveMessageSimulatorCommand.new(
        session_id: { value: session_id },
        customer_number: phone_number,
        channel_number: { number: messaging_channel[:number], channel: channel_enum },
        cost: cost,
        parts: Utils::IncomingMessageSerializer.serialize(message_parts)
      )

      send_command(:receive_message, command)
    end

    # Simulates receiving of a payment.
    # @param phone_number [String] Phone number that sent the message
    # @param payment_channel [Hash] Details of the payment channel used
    # @param transaction_id [String] Transaction id of the simulation
    # @param value [Array] Details on the transaction value and currency
    # @param status [String] Status of the transaction
    def receive_payment(phone_number:, payment_channel:, transaction_id:, value:, status:)
      Utils.assert_keys_present(value, %i[currency_code amount], "value", strict: true)
      Utils.assert_keys_present(payment_channel, %i[number channel], "payment_channel", strict: true)

      number, channel = payment_channel.values_at(:number, :channel)
      channel = Utils.get_enum_value(P::PaymentChannel, channel, "PAYMENT_CHANNEL")

      command = P::ReceivePaymentSimulatorCommand.new(
        transaction_id: transaction_id,
        customer_number: phone_number,
        status: Utils.get_enum_value(P::PaymentStatus, status, "PAYMENT_STATUS"),
        value: value,
        channel_number: { number: number, channel: channel }
      )
      send_command(:receive_payment, command)
    end

    # Simulates updating of a payment status.
    # @param transaction_id [String] Transaction id of the simulation
    # @param status [String] Status of the transaction
    def update_payment_status(transaction_id, status)
      status_val = Utils.get_enum_value(P::PaymentStatus, status, "PAYMENT_STATUS")
      command =  P::UpdatePaymentStatusSimulatorCommand.new(transaction_id: transaction_id, status: status_val)

      send_command(:update_payment_status, command)
    end
  end
end

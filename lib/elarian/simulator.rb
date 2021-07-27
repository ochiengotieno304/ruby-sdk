# frozen_string_literal: true

module Elarian
  class Simulator < Client
    include Utils::AppToServerCommandsHelper

    def initialize(org_id:, app_id:, api_key:, options: nil)
      events = %i[send_message make_voice_call send_customer_payment send_channel_payment checkout_payment]
      super(org_id: org_id, app_id: app_id, api_key: api_key, options: options, events: events)
    end

    def receive_message(phone_number:, messaging_channel:, session_id:, message_parts:, cost: nil)
      Utils.assert_only_valid_keys_present(cost, "cost", %i[currency_code amount]) unless cost.nil?

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

    private

    def client
      self
    end
  end
end

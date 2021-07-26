# frozen_string_literal: true

module Elarian
  class Elarian
    EXPECTED_EVENTS = %i[
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
    ].freeze

    attr_reader :client

    def initialize(org_id:, app_id:, api_key:, is_simulator: nil, simplex_mode: nil, options: {}) # rubocop:disable Metrics/ParameterLists
      @client = Client.new(
        org_id: org_id,
        api_key: api_key,
        app_id: app_id,
        is_simulator: is_simulator,
        simplex_mode: simplex_mode,
        options: options
      )
    end

    def on(event, handler)
      raise ArgumentError, "Invalid handler provided. Handler must be callable." unless handler.respond_to?(:call)

      if Client::EXPECTED_EVENTS.include?(event&.to_sym)
        @client.on(event, handler)
      elsif EXPECTED_EVENTS.include?(event&.to_sym)
        RequestHandler.instance.add_handler(event, handler)
      else
        raise ArgumentError, "Unrecognized event (#{event})"
      end
    end
  end
end

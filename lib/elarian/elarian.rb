# frozen_string_literal: true

module Elarian
  class Elarian < Client
    attr_reader :client

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
  end
end

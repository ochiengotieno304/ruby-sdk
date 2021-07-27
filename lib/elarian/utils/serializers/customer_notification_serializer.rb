# frozen_string_literal: true

module Elarian
  module Utils
    class CustomerNotificationSerializer
      class << self
        private :new

        def serialize(event, data)
          new(event, data).serialize
        end
      end

      def initialize(event, data)
        @event = event
        @data = data.dup
      end

      def serialize
        serialize_customer_number
        send("serialize_#{@event}") if known_events.include? @event
        [@event, @data]
      end

      private

      def known_events
        app_events = %i[
          messaging_consent_update
          messaging_session_ended
          messaging_session_renewed
          messaging_session_started
          message_status
          received_message
          sent_message_reaction

          payment_status
          received_payment
          wallet_payment_status

          reminder

          customer_activity
        ]
        simulator_events = %i[
          send_message
          make_voice_call

          send_customer_payment
          send_channel_payment
          checkout_payment
        ]
        app_events.concat(simulator_events)
      end

      def serialize_messaging_consent_update
        @data[:session_id] = @data.dig(:session_id, :value)
        @data[:status] = Utils.get_enum_string(
          P::MessagingConsentUpdateStatus, @data[:status], "MESSAGING_CONSENT_UPDATE_STATUS"
        )
        @data[:update] = Utils.get_enum_string(P::MessagingConsentUpdate, @data[:update], "MESSAGING_CONSENT_UPDATE")
        serialize_channel_number(P::MessagingChannel, "MESSAGING_CHANNEL")
      end

      def serialize_messaging_session_ended
        @data[:session_id] = @data.dig(:session_id, :value)
        @data[:expires_at] = Utils.pb_to_time(@data[:expires_at]) if @data[:expires_at]
        @data[:duration] = Utils.pb_duration_seconds(@data[:duration]) if @data[:duration]
        if @data[:reason]
          @data[:reason] = Utils.get_enum_string(
            P::MessagingSessionEndReason, @data[:reason], "MESSAGING_SESSION_END_REASON"
          )
        end
        serialize_channel_number(P::MessagingChannel, "MESSAGING_CHANNEL")
      end
      alias serialize_messaging_session_renewed serialize_messaging_session_ended
      alias serialize_messaging_session_started serialize_messaging_session_ended

      def serialize_message_status
        @data[:status] = Utils.get_enum_string(P::MessageDeliveryStatus, @data[:status], "MESSAGE_DELIVERY_STATUS")
      end

      def serialize_received_message # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        @data[:session_id] = @data.dig(:session_id, :value)
        @data[:in_reply_to] = @data.dig(:in_reply_to, :value)
        @data[:parts] = @data[:parts].map { |part| ReceivedMessagePartsSerializer.serialize(part) }

        channel, = serialize_channel_number(P::MessagingChannel, "MESSAGING_CHANNEL")
        switch_to_more_specific_event(channel)
        case channel.downcase
        when "ussd"
          @data[:input] = @data[:parts].find { |part| part[:ussd] }[:ussd]
        when "voice"
          @data[:voice] = @data[:parts].find { |part| part[:voice] }[:voice]
        when "sms", "whatsapp", "telegram", "fb_messenger"
          @data[:text] = @data[:parts].find { |part| part[:text] }&.dig(:text)
          @data[:media] = @data[:parts].find { |part| part[:media] }&.dig(:media)
          @data[:location] = @data[:parts].find { |part| part[:location] }&.dig(:location)
        when "email"
          @data[:email] = @data[:parts].find { |part| part[:email] }[:email]
        end
        @data.delete :parts
      end

      # receive_message events can be made more specific based on channel type for that event
      def switch_to_more_specific_event(channel)
        return unless @event == :received_message

        case channel.to_sym
        when :voice
          @event = :voice_call
        when :ussd
          @event = :ussd_session
        when :sms, :fb_messenger, :telegram, :whatsapp, :email
          @event = "received_#{channel}".to_sym
        end
      end

      def serialize_sent_message_reaction
        @data[:reaction] = Utils.get_enum_string(P::MessageReaction, @data[:reaction], "MESSAGE_REACTION")
        serialize_channel_number(P::MessagingChannel, "MESSAGING_CHANNEL")
      end

      def serialize_payment_status
        @data[:status] = Utils.get_enum_string(P::PaymentStatus, @data[:status], "PAYMENT_STATUS")
      end
      alias serialize_wallet_payment_status serialize_payment_status

      def serialize_received_payment
        @data[:status] = Utils.get_enum_string(P::PaymentStatus, @data[:status], "PAYMENT_STATUS")
        serialize_channel_number(P::PaymentChannel, "PAYMENT_CHANNEL")
      end

      def serialize_reminder
        r = @data[:reminder]
        r[:payload] = r.dig(:payload, :value)
        r[:remind_at] = Utils.pb_to_time(r[:remind_at]) if r[:remind_at]
        r[:interval] = GP::Duration.new(r[:interval]).to_f if r[:interval]

        @data[:reminder].merge!(r)
      end

      def serialize_customer_activity
        @data[:session_id] = @data.dig(:session_id, :value)
        serialize_channel_number(P::ActivityChannel, "ACTIVITY_CHANNEL")
      end

      def serialize_send_message
        serialize_channel_number(P::MessagingChannel, "MESSAGING_CHANNEL")
        @data[:session_id] = @data.dig(:session_id, :value)
      end
      alias serialize_make_voice_call serialize_send_message

      def serialize_checkout_payment
        serialize_channel_number(P::MessagingChannel, "PAYMENT_CHANNEL")

        @data[:account] = @data.dig(:account, :value)
      end
      alias serialize_send_channel_payment serialize_checkout_payment
      alias serialize_send_customer_payment serialize_checkout_payment

      def serialize_channel_number(enum_class, enum_prefix)
        return unless @data[:channel_number]

        number, channel = @data[:channel_number].values_at(:number, :channel)
        channel = Utils.get_enum_string(enum_class, channel, enum_prefix)
        @data[:channel_number] = { number: number, channel: channel }
        [channel, number]
      end

      def serialize_customer_number
        return unless @data[:customer_number]

        number, provider, partition = @data[:customer_number].values_at(:number, :provider, :partition)
        provider = Utils.get_enum_string(P::CustomerNumberProvider, provider, "CUSTOMER_NUMBER_PROVIDER") if provider
        partition = partition&.dig(:value)

        @data[:customer_number] = { number: number, provider: provider, partition: partition }
      end
    end
  end

  class ReceivedMessagePartsSerializer
    class << self
      private :new

      def serialize(part)
        new(part).serialize
      end
    end

    def initialize(part)
      @part = part
    end

    def serialize
      part_type = known_part_types.find { |type| @part[type] }
      return unless part_type

      send("serialize_#{part_type}")
    end

    private

    def known_part_types
      %i[ussd location media voice email text]
    end

    def serialize_ussd
      ussd = @part[:ussd]
      {
        ussd: {
          text: ussd.dig(:text, :value),
          status: Utils.get_enum_string(P::UssdSessionStatus, ussd[:status], "USSD_SESSION_STATUS")
        }
      }
    end

    def serialize_location
      location = @part[:location]
      label, address = location.values_at(:label, :address).map { |val| val&.dig(:value) }
      { location: location.merge({ label: label, address: address }) }
    end

    def serialize_media
      media = @part[:media]
      media[:type] = Utils.get_enum_string(P::MediaType, media[:media], "MEDIA_TYPE")
      { media: media }
    end

    def serialize_voice
      voice = @part[:voice]
      serialized = {
        dtmf_digits: voice[:dtmf_digits]&.dig(:value),
        startedAt: (Utils.pb_to_time(voice[:started_at]) if voice[:started_at]),
        recording_url: voice[:recording_url]&.dig(:value),
        status: Utils.get_enum_string(P::VoiceCallStatus, voice[:status], "VOICE_CALL_STATUS"),
        direction: Utils.get_enum_string(P::CustomerEventDirection, voice[:direction], "CUSTOMER_EVENT_DIRECTION"),
        hangup_cause: Utils.get_enum_string(P::VoiceCallHangupCause, voice[:hangup_cause], "VOICE_CALL_HANGUP_CAUSE")
      }

      { voice: voice.merge(serialized) }
    end

    def serialize_email
      { email: @part[:email] }
    end

    def serialize_text
      { text: @part[:text] }
    end
  end
end

# frozen_string_literal: true

module Elarian
  module Utils
    GP = Google::Protobuf

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
        @data
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
        @data[:expires_at] = pb_to_time(@data[:expires_at]) if @data[:expires_at]
        @data[:duration] = pb_duration_seconds(@data[:duration]) if @data[:duration]
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

      def serialize_received_message
        @data[:session_id] = @data.dig(:session_id, :value)
        @data[:in_reply_to] = @data.dig(:in_reply_to, :value)

        number, channel = @data[:channel_number].values_at(:number, :channel)
        channel = Utils.get_enum_string(P::MessagingChannel, channel, "MESSAGING_CHANNEL")
        @data[:channel_number] = { number: number, channel: channel }

        known_channels = %i[ussd voice sms whatsapp telegram fb_messenger email]
        if known_channels.include? channel
          @data[:input] = @data[:parts].find{ |part| part[channel] }[channel]
        end
        @data.delete :parts
      end

      def serialize_sent_message_reaction
        @data[:reaction] = Utils.get_enum_string(P::MessageReaction, @data[:reaction],"MESSAGE_REACTION" )
        serialize_channel_number(P::MessagingChannel, "MESSAGING_CHANNEL")
      end

      def serialize_payment_status
        @data[:status] = Utils.get_enum_string(P::PaymentStatus, @data[:status], "PAYMENT_STATUS")
      end
      alias_method :serialize_wallet_payment_status, :serialize_payment_status

      def serialize_received_payment
        @data[:status] = Utils.get_enum_string(P::PaymentStatus, @data[:status], "PAYMENT_STATUS")
        serialize_channel_number(P::PaymentChannel, "PAYMENT_CHANNEL")
      end

      def serialize_reminder
        r = @data[:reminder]
        r[:payload] = r.dig(:payload, :value)
        r[:remind_at] = pb_to_time(r[:remind_at]) if r[:remind_at]
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
      alias_method :serialize_make_voice_call, :serialize_send_message

      def serialize_checkout_payment
        serialize_channel_number(P::MessagingChannel, "PAYMENT_CHANNEL")

        @data[:account] = @data.dig(:account, :value)
      end
      alias_method :serialize_send_channel_payment, :serialize_checkout_payment
      alias_method :serialize_send_customer_payment, :serialize_checkout_payment

      def serialize_channel_number(enum_class, enum_prefix)
        return unless @data[:channel_number]

        number, channel = @data[:channel_number].values_at(:number, :channel)
        channel = Utils.get_enum_string(enum_class, channel, enum_prefix)
        @data[:channel_number] = { number: number, channel: channel}
      end

      def serialize_customer_number
        return unless @data[:customer_number]

        number, provider, partition = @data[:customer_number].values_at(:number, :provider, :partition)
        provider = Utils.get_enum_string(P::CustomerNumberProvider, provider, "CUSTOMER_NUMBER_PROVIDER") if provider
        partition = partition&.dig(:value)

        @data[:customer_number] = { number: number, provider: provider, partition: partition }
      end

      # @param pb_timestamp [Hash] the <seconds, nanoseconds> tuple representing the protobuf timestamp
      def pb_to_time(pb_timestamp)
        GP::Timestamp.new(pb_timestamp).to_time.utc
      end

      def pb_duration_seconds(pb_duration)
        GP::Duration.new(pb_duration).to_f
      end
    end
  end
end

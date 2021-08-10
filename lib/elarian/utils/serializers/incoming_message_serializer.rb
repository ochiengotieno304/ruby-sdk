# frozen_string_literal: true

module Elarian
  module Utils
    class IncomingMessageSerializer
      class << self
        private :new

        def serialize(message_parts)
          message_parts.map { |part| new(part).serialize }
        end
      end

      def initialize(part)
        @part = part
        @serialized = P::InboundMessageBody.new
      end

      def serialize
        %i[text ussd media location email voice].each do |type|
          send("s_#{type}") if @part.key?(type)
        end
        @serialized
      end

      private

      def s_text
        @serialized.text = @part[:text]
      end

      def s_ussd
        status, text = @part[:ussd].values_at(:status, :text)
        status = Utils.get_enum_value(P::UssdSessionStatus, status, "USSD_SESSION_STATUS") unless status.nil?
        @serialized.ussd = P::UssdInputMessageBody.new(status: status, text: { value: text })
      end

      def s_media
        url, type = @part[:media].values_at(:url, :type)
        type = Utils.get_enum_value(P::MediaType, type, "MEDIA_TYPE") unless type.nil?
        @serialized.media = P::MediaMessageBody.new(url: url, media: type)
      end

      def s_location
        lat, long, label, addr = @part[:location].values_at(:latitude, :longitude, :label, :address)
        label = { value: label } unless label.nil?
        addr = { value: addr } unless addr.nil?
        @serialized.location = P::LocationMessageBody.new(latitude: lat, longitude: long, label: label, address: addr)
      end

      def s_email
        sub, plain, html, cc, bcc, attach = @part[:email].values_at(:subject, :plain, :html, :cc, :bcc, :attachments)
        @serialized.email = P::EmailMessageBody.new(
          subject: sub, body_plain: plain, body_html: html, cc_list: cc, bcc_list: bcc, attachments: attach
        )
      end

      def s_voice
        @serialized.voice = VoiceMessageSerializer.serialize(@part[:voice])
      end
    end

    class VoiceInputMessageSerializer
      class << self
        private :new

        def serialize(voice_message)
          new(voice_message).serialize
        end
      end

      def initialize(voice_message)
        @message = voice_message
        @serialized = P::VoiceCallInputMessageBody.new
      end

      def serialize
        %i[direction status started_at hangup_cause dtmf_digits recording_url dial_data queue_data].each do |key|
          send "s_#{key}" if @message.key?(key)
        end
        @serialized
      end

      private

      def s_direction
        @serialized.direction = Utils.get_enum_value(
          P::CustomerEventDirection, @message[:direction], "CUSTOMER_EVENT_DIRECTION"
        )
      end

      def s_status
        @serialized.status = Utils.get_enum_value(P::VoiceCallStatus, @message[:status], "VOICE_CALL_STATUS")
      end

      def s_started_at
        Utils.assert_type(@message[:started_at], "started_at", Time)
        @serialized.started_at = @message[:started_at]
      end

      def s_hangup_cause
        @serialized.hangup_cause = Utils.get_enum_value(
          P::VoiceCallHangupCause, @message[:hangup_cause], "VOICE_CALL_HANGUP_CAUSE"
        )
      end

      def s_dtmf_digits
        @serialized.dtmf_digits = Google::Protobuf::StringValue.new(value: @message[:dtmf_digits])
      end

      def s_recording_url
        @serialized.recording_url = Google::Protobuf::StringValue.new(value: @message[:recording_url])
      end

      def s_dial_data
        dest, started, dur = @message[:dial_data].values_at(:destination_number, :started_at, :duration)

        Utils.assert_type(started, "started_at", Time)
        Utils.assert_type(dur, "duration", Numeric)

        @serialized.dial_data = P::VoiceCallDialInput.new(destination_number: dest, started_at: started, duration: dur)
      end

      def s_queue_data
        enq_at, deq_at, deq_to_num, deq_to_session_id, duration = @message[:queue_data].values_at(
          :enqueued_at, :dequeued_at, :dequeued_to_number, :dequeued_to_sessionId, :queue_duration
        )

        if deq_to_session_id.nil?
          deq_to_session_id = @message[:dequeued_to_session_id] # maybe user decided on proper snake_case
        end

        Utils.assert_type(enq_at, "enqueued_at", Time)
        Utils.assert_type(deq_at, "dequeued_at", Time)
        Utils.assert_type(duration, "queue_duration", Numeric)

        deq_to_num = { value: deq_to_num } if deq_to_num
        deq_to_session_id = { value: deq_to_session_id } if deq_to_session_id

        @serialized.queue_data = P::VoiceCallQueueInput.new(
          enqueued_at: enq_at,
          dequeued_at: deq_at,
          dequeued_to_number: deq_to_num,
          dequeued_to_sessionId: deq_to_session_id,
          queue_duration: duration
        )
      end
    end
  end
end

# frozen_string_literal: true
require_relative "service/messaging_model_pb"

module Elarian
  module Utils
    P = Com::Elarian::Hera::Proto

    class VoiceMessageSerializer
      class << self
        private :new

        def serialize(voice)
          voice.map { |action| new(action).serialize }
        end
      end

      def initialize(action)
        @action = action.freeze
      end

      def serialize
        keys = %i[say play get_digits get_recording dial record_session enqueue dequeue reject redirect]
        key = keys.find { |key| @action.key? key }
        return unless key
        P::VoiceCallAction.new(key => send("serialize_#{key}"))
      end

      private

      def serialize_say
        serialize_say_payload(@action[:say])
      end

      def serialize_say_payload(payload)
        text = payload[:text]
        play_beep = payload.fetch(:play_beep, false)
        voice = Utils.get_enum_value(P::TextToSpeechVoice, payload.fetch(:voice, "FEMALE"), "TEXT_TO_SPEECH_VOICE")

        P::SayCallAction.new(text: text, play_beep: play_beep, voice: voice)
      end

      def serialize_play
        P::PlayCallAction.new(url: @action[:play][:url])
      end

      def serialize_get_digits
        get_digits = @action[:get_digits]

        prompt = if get_digits.key? :say
          {say: serialize_say_payload(get_digits[:say])}
        elsif get_digits.key? :play
          {play: P::PlayCallAction.new(url: get_digits[:play][:url])}
        end

        P::GetDigitsCallAction.new(
          num_digits: {value: get_digits[:num_digits]},
          timeout: get_digits.fetch(:timeout, 0),
          finish_on_key: {value: get_digits.fetch(:finish_on_key, "#")},
          **(prompt || {})
        )
      end

      def serialize_get_recording
        return unless @action.key? :get_recording

        get_recording = @action[:get_recording]

        prompt = if get_recording.key? :say
          {say: serialize_say_payload(get_recording[:say])}
        elsif get_recording.key? :play
          {play: P::PlayCallAction.new(url: get_recording[:play][:url])}
        end

        P::GetRecordingCallAction.new(
          timeout: get_recording.fetch(:timeout, 0),
          max_length: get_recording.fetch(:max_length, 3600),
          finish_on_key: {value: get_recording.fetch(:finish_on_key, "#")},
          play_beep: get_recording.fetch(:play_beep, false),
          trim_silence: get_recording.fetch(:trim_silence, true),
          **(prompt || {})
        )
      end

      def serialize_dial
        dial = @action[:dial]
        customer_numbers = dial[:customer_numbers]&.map do |num|
          provider = num.fetch(:provider, "UNSPECIFIED")
          P::CustomerNumber.new(
            number: num[:number],
            provider: Utils.get_enum_value(P::CustomerNumberProvider, provider,"CUSTOMER_NUMBER_PROVIDER"),
            partition: num[:partition]
          )
        end
        P::DialCallAction.new(
          record: dial.fetch(:record, false),
          sequential: dial.fetch(:sequential, true),
          ringback_tone: {value: dial[:ringback_tone]},
          caller_id: {value: dial[:caller_id]},
          max_duration: {value: dial.fetch(:max_duration, 3600)},
          customer_numbers: customer_numbers
        )
      end

      def serialize_enqueue
        enqueue = @action[:enqueue]
        hm, qn = enqueue.values_at(:hold_music, :queue_name).map { |value| {value: value} }
        P::EnqueueCallAction.new(hold_music: hm, queue_name: qn)
      end

      def serialize_dequeue
        dequeue = @action[:dequeue]
        channel, number = dequeue.fetch(:channel, {}).values_at(:channel, :number)
        channel_number = P::MessagingChannelNumber.new(
          number: number,
          channel: Utils.get_enum_value(P::MessagingChannel, channel || "UNSPECIFIED", "MESSAGING_CHANNEL")
        )
        P::DequeueCallAction.new(
          record: dequeue.fetch(:record, false),
          queue_name: {value: dequeue[:queue_name]},
          channel_number: channel_number
        )
      end
    end
  end
end

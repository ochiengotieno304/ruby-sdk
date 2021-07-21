# frozen_string_literal: true

module Elarian
  module Utils
    P = Com::Elarian::Hera::Proto

    class OutgoingMessageSerializer
      class << self
        private :new

        def serialize(message)
          new(message).serialize
        end
      end

      def initialize(message)
        @message = message
        @body = message.fetch(:body, {})
      end

      def serialize
        P::OutboundMessage.new(
          labels: @message.fetch(:labels, []),
          provider_tag: {value: @message.fetch(:provider_tag, "")},
          reply_token: {value: @message.fetch(:reply_token, "")},
          reply_prompt: reply_prompt,
          body: serialize_body
        )
      end

      def reply_prompt
        return unless @message.key? :reply_prompt

        prompt = @message[:reply_prompt]
        action = Utils.get_enum_value(
          P::PromptMessageReplyAction, prompt.fetch(:action, "UNKNOWN"), "PROMPT_MESSAGE_REPLY_ACTION"
        )
        menu = prompt.fetch(:menu, []).map do |item|
          entry = if item.key? :text
            {text: item[:text]}
          elsif item.key? :media
            {media: Utils.get_enum_value(P::MediaType, item[:media].fetch(:type,"UNSPECIFIED"), "MEDIA_TYPE")}
          end
          P::PromptMessageMenuItemBody.new(entry || {})
        end
        P::OutboundMessageReplyPrompt.new(action: action, menu: menu)
      end

      def serialize_body
        key = %i[text url ussd media location template email voice].find { |key| @body.key? key }
        return unless key
        P::OutboundMessageBody.new(key => send("serialize_#{key}"))
      end

      def serialize_text
        @body[:text]
      end

      def serialize_url
        @body[:url]
      end

      def serialize_ussd
        ussd = @body[:ussd].select { |key, _| key == :text || key == :is_terminal }
        P::UssdMenuMessageBody.new(ussd)
      end

      def serialize_media
        media = @body[:media]
        type = Utils.get_enum_value(P::MediaType, media.fetch(:type, "UNSPECIFIED"), "MEDIA_TYPE")
        P::MediaMessageBody.new(url: media[:url], media: type)
      end

      def serialize_location
        lat, long, label, address = @body[:location].values_at(:latitude, :longitude, :label, :address)
        label, address = [label, address].map { |value| {value: value} }
        Utils.assert_type(lat, "latitude", Numeric)
        Utils.assert_type(long, "longitude", Numeric)
        P::LocationMessageBody.new(latitude: lat, longitude: long, label: label, address: address)
      end

      def serialize_template
        template = P::TemplateMessageBody.new(id: @body[:template][:id])
        @body[:template][:params]&.each { |key, val| template.params[key] = val }
        template
      end

      def serialize_email
        sub, plain, html, cc, bcc, attach = @body[:email].values_at(:subject, :plain, :html, :cc, :bcc, :attachments)
        P::EmailMessageBody.new(
          subject: sub, body_plain: plain, body_html: html, cc_list: cc, bcc_list: bcc, attachments: attach
        )
      end

      def serialize_voice
        P::VoiceCallDialplanMessageBody.new(actions: VoiceMessageSerializer.serialize(@body[:voice]))
      end
    end
  end
end

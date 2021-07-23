# frozen_string_literal: true

module Elarian
  Proto = Com::Elarian::Hera::Proto

  class ResponseParser
    class << self
      private :new

      def parse(payload)
        new(payload)
      end
    end

    attr_reader :data

    def initialize(payload)
      @payload = payload
      decoded = Proto::AppToServerCommandReply.decode(payload.data_utf8).to_h

      # only one key in AppToServerCommandReply can have it's value being non-nil
      key = decoded.keys.find { |k| !decoded[k].nil? }
      @data = decoded[key]
    end

    def error?
      !@data[:status]
    end

    def error_message
      return unless error?

      @data[:description]
    end
  end
end

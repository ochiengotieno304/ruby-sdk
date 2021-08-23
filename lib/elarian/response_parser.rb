# frozen_string_literal: true

module Elarian
  class ResponseParser
    class << self
      private :new

      def parse(payload)
        new(payload)
      end
    end

    attr_reader :data

    def initialize(payload)
      @data = decode(payload)
    end

    def error?
      !@data.status if @data.respond_to? :status
    end

    def error_message
      return unless error?

      @data.description
    end

    private

    def decode(payload)
      decoded = P::AppToServerCommandReply.decode(payload.data_utf8)
      field = decoded.send(:entry)
      decoded.send(field)
    end
  end

  class SimulatorResponseParser < ResponseParser
    private

    def decode(payload)
      P::SimulatorToServerCommandReply.decode(payload.data_utf8)
    end
  end
end

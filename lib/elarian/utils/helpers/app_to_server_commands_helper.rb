# frozen_string_literal: true

module Elarian
  module Utils
    module AppToServerCommandsHelper
      def send_command(command_name, command)
        req = command_class.new(command_name => command)
        res = client.send_request(req)
        parse_response(res)
      end

      # Wraps the provided response subject, and returns a new response subject that emits a parsed response message
      #
      # @param response_subject [Rx::AsyncSubject] the original async response
      # @return [Rx::Observable] an observable which yields the server's parsed reply data or error message
      def parse_response(response_subject)
        response_subject.map do |payload|
          reply = response_parser.parse(payload)

          # This path will most likely NEVER be taken.
          # This is because Elarian typically sends back errors using RSocket::ErrorFrame frames; and the way we handle
          # error frames is by calling response_subject.on_error directly: See RSocket::RSocketRequester#handle_error.
          #
          # But just in case an error is sent using a normal RSocket::PayloadFrame frame, let's leave this here!
          raise reply.error_message if reply.error?

          reply.data&.to_h
        end
      end

      def command_class
        return P::SimulatorToServerCommand if client.is_simulator

        P::AppToServerCommand
      end

      def response_parser
        return SimulatorResponseParser if client.is_simulator

        ResponseParser
      end
    end
  end
end

# frozen_string_literal: true

module Elarian
  class Requester < RSocket::RSocketRequester
    attr_reader :connected

    def initialize(metadata_encoding, data_encoding, setup_payload, resp_handler_block)
      super
      @connected = false
      @responder_handler = RequestHandler.instance
    end
  end

  def self.connect(rsocket_uri, metadata_encoding:, data_encoding:, setup_payload:, &resp_handler_block)
    uri = URI.parse(rsocket_uri)
    EventMachine.connect(uri.hostname, uri.port, Requester, metadata_encoding, data_encoding, setup_payload,
                         resp_handler_block)
  end
end

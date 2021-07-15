# frozen_string_literal: true

require_relative "./utils/custom_load_paths"
require "app_socket_pb"
require "google/protobuf"
require "rsocket/requester"
require "eventmachine"
module Elarian
  class Client
    def initialize(org_id:, app_id:, api_key:, options: {})
      @org_id = org_id
      @app_id = app_id
      @api_key = api_key
      @options = default_options.merge(options)

      # TODO: need to figure out how/when Elarian users simulator mode
      @is_simulator = false
    end

    def connect
      setup = Com::Elarian::Hera::Proto::AppConnectionMetadata.new(
        org_id: @org_id,
        app_id: @app_id,
        api_key: Google::Protobuf::StringValue.new(value: @api_key),
        simplex_mode: true,
        simulator_mode: @is_simulator
      )
      RSocket.connect(
        "#{ENV["URL"]}:#{ENV["PORT"]}",
        metadata_encoding: "application/octet-stream",
        data_encoding: "application/octet-stream",
        setup_payload: payload_of(setup.to_proto, nil)
      )
    end

    protected

    def default_options
      { allow_notifications: true }
    end
  end
end

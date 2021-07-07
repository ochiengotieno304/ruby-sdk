# frozen_string_literal: true

require_relative "./utils/custom_load_paths"
require "app_socket_pb"
require "google/protobuf"
require "rsocket/requester"
require "eventmachine"
module Elarian
  class Client
    EXPECTED_EVENTS = %w[pending error connecting connected closed].freeze

    def initialize(org_id:, app_id:, api_key:, options: {})
      @org_id = org_id
      @app_id = app_id
      @api_key = api_key
      @options = default_options.merge(options)
      @simplex_mode = !@options[:allow_notifications]

      # TODO: need to figure out how/when Elarian users simulator mode
      @is_simulator = false
      @handlers = {}
    end

    def connect
      set_on_connected_handler
      set_on_closed_handler
      # TODO: Need to set on_error handler. How/Where/When do we sense that a connection error has occured?
      EM.defer { @handlers[:pending].call } if @handlers[:pending]
      @socket = Elarian.connect(
        "#{ENV["URL"]}:#{ENV["PORT"]}",
        metadata_encoding: "application/octet-stream",
        data_encoding: "application/octet-stream",
        setup_payload: payload_of(app_connection_metadata.to_proto, nil)
      )
      EM.defer { @handlers[:connecting].call } if @handlers[:connecting]
      @socket
    end

    def on(event, handler)
      raise ArgumentError, "Unrecognized event (#{event})" unless EXPECTED_EVENTS.include?(event&.to_s)
      raise ArgumentError, "Invalid handler provided. Handler must be callable." unless handler.respond_to?(:call)

      @handlers[event.to_sym] = handler
    end

    def send_command(data)
      raise "Client is not connected" unless connected?

      @socket.request_response(payload_of(data.to_proto, nil))
    end

    def disconnect
      @socket&.close_connection
    end

    private

    def app_connection_metadata
      Com::Elarian::Hera::Proto::AppConnectionMetadata.new(
        org_id: @org_id,
        app_id: @app_id,
        api_key: Google::Protobuf::StringValue.new(value: @api_key),
        simplex_mode: @simplex_mode,
        simulator_mode: @is_simulator
      )
    end

    def default_options
      { allow_notifications: true }
    end

    def connected?
      @socket&.connected
    end

    def set_on_closed_handler
      handler = @handlers[:closed]
      Elarian::Requester.class_eval do
        define_method(:unbind) do
          super()
          @connected = false
          EM.defer { handler.call } if handler
        end
      end
    end

    def set_on_connected_handler
      handler = @handlers[:connected]
      Elarian::Requester.class_eval do
        # TODO: Change this to ssl_handshake_completed, or other appropriate callback when we start using TLS
        define_method(:connection_completed) do
          super()
          @connected = true
          EM.defer { handler.call } if handler
        end
      end
    end
  end
end


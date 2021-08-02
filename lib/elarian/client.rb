# frozen_string_literal: true

module Elarian
  # Client class that handles connections to Elarian backend
  class Client
    # @return [Boolean] Indicates if client is a simulator or not
    attr_reader :is_simulator

    # @param org_id The Organization id
    # @param api_key The generated API key from the dashboard
    # @param app_id The app id generated from the dashboard
    # @param events The expected events
    # @param options Extra options passed to the client
    def initialize(org_id:, app_id:, api_key:, events: [], options: {})
      @org_id = org_id
      @app_id = app_id
      @api_key = api_key
      @options = default_options.merge(options)
      @simplex_mode = !@options[:allow_notifications]
      @is_simulator = @options[:is_simulator]
      @handlers = {}

      @connection_events = %i[pending error connecting connected closed].freeze
      @events = events

      validate

      RequestHandler.instance.client = self
    end

    # Connects to Elarian
    def connect
      set_handlers
      EM.defer(@handlers[:pending]) if @handlers[:pending]
      @socket = ::Elarian.connect(
        "#{ENV["URL"]}:#{ENV["PORT"]}",
        metadata_encoding: "application/octet-stream",
        data_encoding: "application/octet-stream",
        setup_payload: payload_of(app_connection_metadata.to_proto, nil)
      )
      EM.defer(@handlers[:connecting]) if @handlers[:connecting]
      @socket
    end

    # Sets handlers for events
    # @param event [String] The event to be registered
    # @param handler The handler function
    def on(event, handler)
      raise ArgumentError, "Unrecognized event (#{event})" unless (@connection_events + @events).include?(event&.to_sym)
      raise ArgumentError, "Invalid handler provided. Handler must be callable." unless handler.respond_to?(:call)

      if @connection_events.include?(event&.to_sym)
        @handlers[event.to_sym] = handler
      else
        RequestHandler.instance.register_handler(event, handler)
      end
    end

    # Sends request to Elarian
    def send_request(data)
      raise "Client is not connected" unless connected?

      @socket.request_response(payload_of(data.to_proto, nil))
    end

    # Disconnects client from Elarian
    def disconnect
      @socket&.close_connection
    end

    # Checks if client if connected
    def connected?
      @socket&.connected
    end

    private

    def client
      self
    end

    def validate
      { app_id: @app_id, org_id: @org_id, api_key: @api_key }.each do |param_name, value|
        Utils.assert_type(value, param_name, String)
      end
    end

    def app_connection_metadata
      Com::Elarian::Hera::Proto::AppConnectionMetadata.new(
        org_id: @org_id,
        app_id: @app_id,
        api_key: { value: @api_key },
        simplex_mode: @simplex_mode,
        simulator_mode: @is_simulator
      )
    end

    def default_options
      {
        allow_notifications: true,
        is_simulator: false
      }
    end

    def set_handlers
      set_on_connected_handler
      set_on_closed_handler
      set_on_error_handler
    end

    def set_on_closed_handler
      handler = @handlers[:closed]
      Requester.class_eval do
        define_method(:unbind) do
          super()
          @connected = false
          EM.defer(handler) if handler
        end
      end
    end

    def set_on_connected_handler
      handler = @handlers[:connected]
      Requester.class_eval do
        # TODO: Change this to ssl_handshake_completed, or other appropriate callback when we start using TLS
        define_method(:connection_completed) do
          super()
          @connected = true
          EM.defer(handler) if handler
        end
      end
    end

    def set_on_error_handler
      handler = @handlers[:error]
      Requester.class_eval do
        define_method(:handle_error) do |error_frame|
          err, is_connection_error = super(error_frame)
          if is_connection_error
            raise err if handler.nil?

            EM.defer(-> { handler.call(err) })
          end
        end
      end
    end
  end
end

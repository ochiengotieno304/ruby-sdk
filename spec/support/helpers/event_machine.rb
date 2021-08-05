# frozen_string_literal: true

module Helpers
  module EventMachine
    @connected_clients = {}

    class << self
      include ::Helpers::Elarian

      def start_em_loop
        return if EM.reactor_running?

        Thread.new do
          puts "Starting event loop"
          EM.run
          puts "Event loop stopped"
        end

        trap(:INT) { disconnect_and_stop_loop }
        trap(:TERM) { disconnect_and_stop_loop }

        until EM.reactor_running?; end
      end

      def disconnect_and_stop_loop
        @connected_clients.each_value { |client| disconnect(client) }

        return unless EM.reactor_running?

        until EM.defers_finished?; end

        puts "Stopping event loop"
        EM.stop
      end

      def disconnect(client)
        return unless client.connected?

        client.disconnect

        while client.connected? && !EM.defers_finished?; end
        @connected_clients.delete(client.object_id)
      end

      def connect(client)
        return if client.connected?

        client.connect

        until client.connected? && EM.defers_finished?; end
        @connected_clients[client.object_id] = client # rubocop:disable Lint/HashCompareByIdentity
      end

      # returns a connected client used for testing
      def get_client
        @default_client ||= ::Elarian::Client.new(connection_credentials)
        @default_client.on(:error, ->(error) { raise error })
        connect(@default_client)
        @default_client
      end
    end
  end
end

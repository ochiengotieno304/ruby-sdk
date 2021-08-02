# frozen_string_literal: true

require "singleton"

module Helpers
  module EventMachine
    @connected_clients = {}

    class << self
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
        return unless EM.reactor_running?

        puts "Stopping event loop"
        until EM.defers_finished?; end
        return EM.stop unless @connected_clients.values.any?(&:connected?)

        @connected_clients.each_value { |client| disconnect(client) }
      end

      def disconnect(client)
        return unless EM.reactor_running? && client.connected?

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
    end
  end
end

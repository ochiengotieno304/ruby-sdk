# frozen_string_literal: true

module Helpers
  module EventHandler
    def new_handler
      Callable.new
    end

    class Callable
      attr_reader :called

      def initialize
        @called = false
      end

      def call(*args) # rubocop:disable Lint/UnusedMethodArgument
        @called = true
      end
    end
  end
end

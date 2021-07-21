# frozen_string_literal: true

require_relative "elarian/ruby/version"
require "rubygems"
require "google/protobuf"
require_relative "elarian/utils/custom_load_paths"
require "app_socket_pb"
require "rsocket/requester"
require "eventmachine"
require_relative "elarian/client"

module Elarian
  class Error < StandardError; end
end

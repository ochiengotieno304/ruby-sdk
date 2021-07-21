# frozen_string_literal: true

require "elarian/ruby/version"
require "rubygems"
require "google/protobuf"
require "elarian/utils/custom_load_paths"
require "app_socket_pb"
require "rsocket/requester"
require "eventmachine"
require "elarian/requester"
require "elarian/client"
require "elarian/customer"
require "elarian/response_parser"
require "elarian/utils/utils"

module Elarian
  class Error < StandardError; end
end

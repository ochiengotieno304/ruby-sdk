# frozen_string_literal: true

require "elarian/ruby/version"
require "rubygems"
require "json"
require "google/protobuf"
require "elarian/utils/custom_load_paths"
require "app_socket_pb"
require "messaging_model_pb"
require "rsocket/requester"
require "eventmachine"
require "elarian/requester"
require "elarian/client"
require "elarian/customer"
require "elarian/response_parser"
require "elarian/utils/utils"
require "elarian/utils/voice_message_serializer"
require "elarian/utils/outgoing_message_serializer"

module Elarian
  class Error < StandardError; end
end

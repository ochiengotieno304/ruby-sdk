# frozen_string_literal: true

require "elarian/ruby/version"
require "rubygems"
require "json"
require "google/protobuf"
require "elarian/utils/custom_load_paths"
require "app_socket_pb"
require "messaging_model_pb"
require "rsocket/payload"
require "rsocket/requester"
require "eventmachine"
require "elarian/requester"
require "elarian/client"
require "elarian/customer"
require "elarian/response_parser"
require "elarian/utils/utils"
require "elarian/utils/serializers/voice_message_serializer"
require "elarian/utils/serializers/outgoing_message_serializer"
require "elarian/utils/serializers/customer_notification_serializer"
require "elarian/request_handler"

module Elarian
  P = Com::Elarian::Hera::Proto

  class Error < StandardError; end
end

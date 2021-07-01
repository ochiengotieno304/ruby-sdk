# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: activity_model.proto

require 'google/protobuf'

require 'google/protobuf/timestamp_pb'
Google::Protobuf::DescriptorPool.generated_pool.build do
  add_file("activity_model.proto", :syntax => :proto3) do
    add_message "com.elarian.hera.proto.ActivityChannelNumber" do
      optional :channel, :enum, 1, "com.elarian.hera.proto.ActivityChannel"
      optional :number, :string, 2
    end
    add_message "com.elarian.hera.proto.CustomerActivity" do
      optional :key, :string, 1
      map :properties, :string, :string, 2
      optional :created_at, :message, 3, "google.protobuf.Timestamp"
    end
    add_enum "com.elarian.hera.proto.ActivityChannel" do
      value :ACTIVITY_CHANNEL_UNSPECIFIED, 0
      value :ACTIVITY_CHANNEL_WEB, 1
      value :ACTIVITY_CHANNEL_MOBILE, 2
    end
  end
end

module Com
  module Elarian
    module Hera
      module Proto
        ActivityChannelNumber = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("com.elarian.hera.proto.ActivityChannelNumber").msgclass
        CustomerActivity = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("com.elarian.hera.proto.CustomerActivity").msgclass
        ActivityChannel = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("com.elarian.hera.proto.ActivityChannel").enummodule
      end
    end
  end
end

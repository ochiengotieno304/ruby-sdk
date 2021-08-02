# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: simulator_socket.proto

require 'google/protobuf'

require 'google/protobuf/duration_pb'
require 'google/protobuf/wrappers_pb'
require 'common_model_pb'
require 'messaging_model_pb'
require 'payment_model_pb'
Google::Protobuf::DescriptorPool.generated_pool.build do
  add_file("simulator_socket.proto", :syntax => :proto3) do
    add_message "com.elarian.hera.proto.SimulatorToServerCommand" do
      oneof :entry do
        optional :receive_message, :message, 1, "com.elarian.hera.proto.ReceiveMessageSimulatorCommand"
        optional :receive_payment, :message, 2, "com.elarian.hera.proto.ReceivePaymentSimulatorCommand"
        optional :update_payment_status, :message, 3, "com.elarian.hera.proto.UpdatePaymentStatusSimulatorCommand"
      end
    end
    add_message "com.elarian.hera.proto.ReceiveMessageSimulatorCommand" do
      optional :customer_number, :string, 1
      optional :channel_number, :message, 2, "com.elarian.hera.proto.MessagingChannelNumber"
      repeated :parts, :message, 3, "com.elarian.hera.proto.InboundMessageBody"
      optional :session_id, :message, 4, "google.protobuf.StringValue"
      optional :cost, :message, 5, "com.elarian.hera.proto.Cash"
      optional :duration, :message, 6, "google.protobuf.Duration"
    end
    add_message "com.elarian.hera.proto.ReceivePaymentSimulatorCommand" do
      optional :transaction_id, :string, 1
      optional :channel_number, :message, 2, "com.elarian.hera.proto.PaymentChannelNumber"
      optional :customer_number, :string, 3
      optional :value, :message, 4, "com.elarian.hera.proto.Cash"
      optional :mode, :enum, 5, "com.elarian.hera.proto.PaymentMode"
      optional :status, :enum, 6, "com.elarian.hera.proto.PaymentStatus"
    end
    add_message "com.elarian.hera.proto.UpdatePaymentStatusSimulatorCommand" do
      optional :transaction_id, :string, 1
      optional :status, :enum, 2, "com.elarian.hera.proto.PaymentStatus"
    end
    add_message "com.elarian.hera.proto.SimulatorToServerCommandReply" do
      optional :status, :bool, 1
      optional :description, :string, 2
      optional :message, :message, 3, "com.elarian.hera.proto.OutboundMessage"
    end
    add_message "com.elarian.hera.proto.ServerToSimulatorNotification" do
      oneof :entry do
        optional :send_message, :message, 1, "com.elarian.hera.proto.SendMessageSimulatorNotification"
        optional :make_voice_call, :message, 2, "com.elarian.hera.proto.MakeVoiceCallSimulatorNotification"
        optional :send_customer_payment, :message, 3, "com.elarian.hera.proto.SendCustomerPaymentSimulatorNotification"
        optional :send_channel_payment, :message, 4, "com.elarian.hera.proto.SendChannelPaymentSimulatorNotification"
        optional :checkout_payment, :message, 5, "com.elarian.hera.proto.CheckoutPaymentSimulatorNotification"
      end
    end
    add_message "com.elarian.hera.proto.ServerToSimulatorNotificationReply" do
    end
    add_message "com.elarian.hera.proto.SendMessageSimulatorNotification" do
      optional :org_id, :string, 1
      optional :customer_id, :string, 2
      optional :message_id, :string, 3
      optional :customer_number, :message, 4, "com.elarian.hera.proto.CustomerNumber"
      optional :channel_number, :message, 5, "com.elarian.hera.proto.MessagingChannelNumber"
      optional :message, :message, 6, "com.elarian.hera.proto.OutboundMessage"
    end
    add_message "com.elarian.hera.proto.MakeVoiceCallSimulatorNotification" do
      optional :org_id, :string, 1
      optional :customer_id, :string, 2
      optional :session_id, :string, 3
      optional :customer_number, :message, 4, "com.elarian.hera.proto.CustomerNumber"
      optional :channel_number, :message, 5, "com.elarian.hera.proto.MessagingChannelNumber"
    end
    add_message "com.elarian.hera.proto.SendCustomerPaymentSimulatorNotification" do
      optional :org_id, :string, 1
      optional :customer_id, :string, 2
      optional :app_id, :string, 3
      optional :transaction_id, :string, 6
      optional :customer_number, :message, 7, "com.elarian.hera.proto.CustomerNumber"
      optional :channel_number, :message, 8, "com.elarian.hera.proto.PaymentChannelNumber"
      optional :value, :message, 9, "com.elarian.hera.proto.Cash"
      oneof :debit_party do
        optional :wallet, :message, 4, "com.elarian.hera.proto.PaymentWalletCounterParty"
        optional :purse, :message, 5, "com.elarian.hera.proto.PaymentPurseCounterParty"
      end
    end
    add_message "com.elarian.hera.proto.SendChannelPaymentSimulatorNotification" do
      optional :org_id, :string, 1
      optional :app_id, :string, 2
      optional :transaction_id, :string, 5
      optional :channel, :enum, 6, "com.elarian.hera.proto.PaymentChannel"
      optional :source, :string, 7
      optional :destination, :string, 8
      optional :account, :message, 9, "google.protobuf.StringValue"
      optional :value, :message, 10, "com.elarian.hera.proto.Cash"
      oneof :debit_party do
        optional :wallet, :message, 3, "com.elarian.hera.proto.PaymentWalletCounterParty"
        optional :purse, :message, 4, "com.elarian.hera.proto.PaymentPurseCounterParty"
      end
    end
    add_message "com.elarian.hera.proto.CheckoutPaymentSimulatorNotification" do
      optional :org_id, :string, 1
      optional :customer_id, :string, 2
      optional :app_id, :string, 3
      optional :transaction_id, :string, 6
      optional :customer_number, :message, 7, "com.elarian.hera.proto.CustomerNumber"
      optional :channel_number, :message, 8, "com.elarian.hera.proto.PaymentChannelNumber"
      optional :value, :message, 9, "com.elarian.hera.proto.Cash"
      oneof :credit_party do
        optional :wallet, :message, 4, "com.elarian.hera.proto.PaymentWalletCounterParty"
        optional :purse, :message, 5, "com.elarian.hera.proto.PaymentPurseCounterParty"
      end
    end
  end
end

module Com
  module Elarian
    module Hera
      module Proto
        SimulatorToServerCommand = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("com.elarian.hera.proto.SimulatorToServerCommand").msgclass
        ReceiveMessageSimulatorCommand = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("com.elarian.hera.proto.ReceiveMessageSimulatorCommand").msgclass
        ReceivePaymentSimulatorCommand = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("com.elarian.hera.proto.ReceivePaymentSimulatorCommand").msgclass
        UpdatePaymentStatusSimulatorCommand = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("com.elarian.hera.proto.UpdatePaymentStatusSimulatorCommand").msgclass
        SimulatorToServerCommandReply = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("com.elarian.hera.proto.SimulatorToServerCommandReply").msgclass
        ServerToSimulatorNotification = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("com.elarian.hera.proto.ServerToSimulatorNotification").msgclass
        ServerToSimulatorNotificationReply = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("com.elarian.hera.proto.ServerToSimulatorNotificationReply").msgclass
        SendMessageSimulatorNotification = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("com.elarian.hera.proto.SendMessageSimulatorNotification").msgclass
        MakeVoiceCallSimulatorNotification = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("com.elarian.hera.proto.MakeVoiceCallSimulatorNotification").msgclass
        SendCustomerPaymentSimulatorNotification = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("com.elarian.hera.proto.SendCustomerPaymentSimulatorNotification").msgclass
        SendChannelPaymentSimulatorNotification = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("com.elarian.hera.proto.SendChannelPaymentSimulatorNotification").msgclass
        CheckoutPaymentSimulatorNotification = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("com.elarian.hera.proto.CheckoutPaymentSimulatorNotification").msgclass
      end
    end
  end
end

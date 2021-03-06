# frozen_string_literal: true

require "singleton"

module Elarian
  class RequestHandler < RSocket::EmptyAbstractHandler
    include Singleton
    attr_reader :handlers, :client

    def initialize
      super
      @handlers = {}
    end

    # Need this to be done only once to avoid subtle bugs
    def client=(client)
      raise "@client already set." unless @client.nil?

      @client = client
    end

    # @param payload [RSocket::Payload]
    # @return [Rx::AsyncSubject]
    def request_response(payload)
      IndividualRequestHandler.handle(payload)
    end

    def register_handler(event, handler)
      @handlers[event.to_sym] = handler
    end

    def simulator?
      @client.is_simulator
    end
  end

  class IndividualRequestHandler
    def self.handle(payload)
      new(payload).handle
    end

    def initialize(payload)
      @async_subject = Rx::AsyncSubject.new

      decoded = decode(payload)
      _, customer_or_purse = retrieve_one_of_field(decoded, :entry)
      @incoming_app_data = customer_or_purse.app_data || {}

      raw_event, raw_notification = retrieve_one_of_field(customer_or_purse, :entry)
      @event, @notification = Utils::CustomerNotificationSerializer.serialize(raw_event, raw_notification.to_h)

      customer_number = @notification[:customer_number] || {}
      @customer = Customer.new(
        client: client,
        id: customer_or_purse.customer_id,
        number: customer_number[:number],
        provider: customer_number[:provider]
      )
    end

    def handle
      handler = RequestHandler.instance.handlers[@event] || default_handler

      EM.defer(-> { handler.call(@notification, @customer, @incoming_app_data, &callback) })

      callback_timeout

      @async_subject.as_observable
    end

    private

    def simulator?
      RequestHandler.instance.simulator?
    end

    def client
      RequestHandler.instance.client
    end

    def default_handler
      ->(notification, customer, app_data) { callback.call(app_data) } # rubocop:disable Lint/UnusedBlockArgument
    end

    # returns a lambda that is invoked when the user-specified handler yields
    def callback
      lambda do |response = nil, data_update = nil|
        res = notification_reply_class.new
        unless simulator?
          res.message = Utils::OutgoingMessageSerializer.serialize(response) unless response.nil?
          res.data_update = if data_update.nil?
                              P::AppDataUpdate.new(data: @incoming_app_data)
                            else
                              P::AppDataUpdate.new(data: { string_val: JSON.dump(data_update) })
                            end

          respond(res)
        end
      end
    end

    def callback_timeout
      EM::Timer.new(15) do
        res = notification_reply_class.new
        res.data_update = P::AppDataUpdate.new(data: @incoming_app_data) unless simulator?

        # Note: Ideally this should only be executed if the async subject has not completed
        # However, Rx does not provide a way to examine the status of a subject.
        # So we always call this and let Rx ignore it if the async subject has been completed.
        respond(res)
      end
    end

    def respond(response)
      @async_subject.on_next(RSocket::Payload.new(response.to_proto.unpack("C*"), nil))
      @async_subject.on_completed
    end

    def decode(payload)
      data = payload.data.pack("C*")
      notification_class.decode(data)
    end

    # Given a Protobuf message that has a one_of field, determine which on the options have been set
    # And return an array containing the option name and value
    def retrieve_one_of_field(pb_message, one_of_field)
      which_field = pb_message.send(one_of_field)

      [which_field, pb_message.send(which_field)]
    end

    def notification_class
      return P::ServerToSimulatorNotification if simulator?

      P::ServerToAppNotification
    end

    def notification_reply_class
      return P::ServerToSimulatorNotificationReply if simulator?

      P::ServerToAppNotificationReply
    end
  end
end

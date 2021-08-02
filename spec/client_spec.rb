# frozen_string_literal: true

require "socket"

RSpec.describe Elarian::Client do
  before(:example) { Singleton.__init__(Elarian::RequestHandler) }

  describe "#new" do
    it "validates that all credentials passed are strings" do
      creds = { api_key: "key", org_id: "org", app_id: "app" }

      expect { described_class.new(**creds) }.not_to raise_error

      expect { described_class.new(**creds.merge(api_key: 1)) }.to raise_error ArgumentError, /Invalid api_key type/
      expect { described_class.new(**creds.merge(org_id: 1)) }.to raise_error ArgumentError, /Invalid org_id type/i
      expect { described_class.new(**creds.merge(app_id: 1)) }.to raise_error ArgumentError, /Invalid app_id type/i
    end

    it "assigns the newly created client to RequestHandler instance's client" do
      client = described_class.new({ api_key: "key", org_id: "org", app_id: "app" })

      expect(Elarian::RequestHandler.instance.client).to equal client
    end
  end

  describe "#on" do
    let(:client) { described_class.new({ api_key: "key", org_id: "org", app_id: "app" }) }

    context "with invalid params" do
      it "rejects unrecognized events" do
        expect { client.on(:dummy_event, -> {}) }.to raise_error ArgumentError, /Unrecognized event.*dummy_event/
      end

      it "rejects handlers that are not callable" do
        expect { client.on(:connected, "invalid_handler") }.to raise_error ArgumentError,
                                                                           /Invalid.*Handler must be callable/
      end
    end

    context "with valid params" do
      it "accepts recognized events and valid handlers" do
        %i[pending error connecting connected closed].each do |event|
          expect { client.on(event, -> {}) }.not_to raise_error
        end
      end
    end
  end

  describe "#connect" do
    before { Helpers::EventMachine.connect(client) }
    after { Helpers::EventMachine.disconnect(client) }

    let(:handlers) do
      %i[pending error connecting connected closed].each_with_object({}) do |event, handlers|
        handlers[event] = new_handler
      end
    end

    context "when connection is successful" do
      let(:client) do
        client = described_class.new(connection_credentials)
        handlers.each { |event, handler| client.on(event, handler) }
        client
      end

      it "calls handlers for :pending, :connecting and :connected but does not call :error or :closed" do
        aggregate_failures do
          %i[pending connecting connected].each do |event|
            expect(handlers[event].called).to be(true), "Expected handler on_#{event} to have been called."
          end

          %i[error closed].each do |event|
            expect(handlers[event].called).to be(false), "Expected handler on_#{event} NOT to have been called."
          end
        end
      end
    end

    context "when connection fails" do
      let(:client) do
        client = described_class.new(api_key: "this", org_id: "should", app_id: "fail")
        handlers.each { |event, handler| client.on(event, handler) }
        client
      end

      it "calls the handlers :pending, :connecting, :connected, :error and :closed" do
        # seems weird to assert that "connected" handler was called
        # But for this case, the way we simulate a connection error is by sending invalid credentials
        # Technically the connection succeeded, but then failed due to invalid creds

        sleep 1

        aggregate_failures do
          %i[pending connecting connected error closed].each do |event|
            expect(handlers[event].called).to be(true), "Expected handler on_#{event} to have been called."
          end
        end
      end
    end
  end

  describe "#disconnect" do
    let(:on_closed_handler) { new_handler }
    let(:client) do
      c = described_class.new(connection_credentials)
      c.on(:closed, on_closed_handler)
      c
    end
    before { Helpers::EventMachine.connect(client) }
    after { Helpers::EventMachine.disconnect(client) } # ensure client gets disconnected event if test fails

    it "closes the connection" do
      expect(client.connected?).to be true
      expect(on_closed_handler.called).to be false

      client.disconnect
      sleep 1

      expect(client.connected?).to be false
      expect(on_closed_handler.called).to be true
    end
  end
end

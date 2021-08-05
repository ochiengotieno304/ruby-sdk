# frozen_string_literal: true

RSpec.describe Elarian::Customer do
  before { Singleton.__init__(Elarian::RequestHandler) }
  let(:client) { Helpers::EventMachine.get_client }
  let(:customer) { described_class.new(client: client, number: "+254700000000", provider: "cellular") }

  describe "#new" do
    it "rejects invalid clients" do
      expect { described_class.new(client: client, id: "some_id") }.not_to raise_error
      expect { described_class.new(client: "bad", id: "some_id") }.to raise_error ArgumentError, "Invalid client"
    end

    it "requires at least ID or Number to be provided" do
      c = Elarian::Client.new(api_key: "", app_id: "", org_id: "")

      expect { described_class.new(client: c, id: "some_id") }.not_to raise_error
      expect { described_class.new(client: c, number: "some_number") }.not_to raise_error

      expect { described_class.new(client: c) }.to raise_error ArgumentError, "id or number must be provided"
    end

    it "rejects unrecognized providers" do
      %w[facebook cellular telegram web email].each do |provider|
        expect { described_class.new(client: client, number: "+25411111111", provider: provider) }.not_to raise_error
      end
      expect { described_class.new(client: client, number: "+25411111111", provider: "invalid") }
        .to raise_error ArgumentError, /Unrecognized provider/
    end
  end
end

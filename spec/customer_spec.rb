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

  describe "#get_state" do
    it "retrieves the customer's state" do
      state = await_done(customer.get_state)
      data = state[:data]

      expect(data).to include(:customer_id, :identity_state, :messaging_state, :payment_state, :activity_state)
    end
  end

  describe "#update_tags" do
    it "rejects invalid tags param" do
      expect { customer.update_tags("the tags") }.to raise_error(/Invalid tags type.*Expected Array/)
      expect { customer.update_tags([{ value: "val", key: "key" }, { value: "val2" }]) }
        .to raise_error(/tags\[1\] missing one or more required keys.*Required keys.*\[:key, :value\]/)
    end

    it "works" do
      tags = [{ key: "consumer_group", value: "heavy_consumer" }]
      res = await_done(customer.update_tags(tags))

      expect(res).to include(:status, :description, :customer_id)
    end
  end

  describe "#delete_tags" do
    it "rejects invalid keys param" do
      expect { customer.delete_tags(1) }.to raise_error(/Invalid keys type.*Expected Array/)
      expect { customer.delete_tags([1, "key"]) }.to raise_error(/Invalid keys\[0\] type.*Expected String/)
    end

    it "works" do
      res = await_done(customer.delete_tags(%w[test consumer_group]))
      expect(res).to include(:status, :description, :customer_id)
      expect(res[:status]).to be true
    end
  end

  describe "#get_tags" do
    it do
      update_tag = { key: "consumer_group", value: "heavy_consumer" }
      await_done(customer.update_tags([update_tag]))

      res = await_done(customer.get_tags)
      expect(res).to be_an Array

      tag = res.find { |el| el.dig(:mapping, :key) == "consumer_group" }
      expect(tag).to be_a Hash

      # TODO: Yuck! Maybe this is a sign that #get_tags should undergo some more parsing
      expect(tag[:mapping]).to eql({ key: update_tag[:key], value: { value: update_tag[:value] } })
    end
  end
end

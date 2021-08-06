# frozen_string_literal: true

RSpec.describe Elarian::Customer do
  before(:context) { Singleton.__init__(Elarian::RequestHandler) }
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

  describe "#add_reminder" do
    let(:reminder) { { key: "test", remind_at: Time.now + 10 } }

    it "rejects invalid reminder params" do
      expect { customer.add_reminder(1) }.to raise_error(/Expected Hash got Integer/)

      with_unknown_key = reminder.merge(foo: "bar")
      with_missing_required_key = { key: "test" }

      expect { customer.add_reminder(with_unknown_key) }.to raise_error(/Invalid reminder property foo/)
      expect { customer.add_reminder(with_missing_required_key) }
        .to raise_error(/Either :key or :remind_at is missing in reminder/)
    end

    it "works" do
      res = await_done(customer.add_reminder(reminder))
      expect(res).to include(:status, :description, :customer_id)
      expect(res[:status]).to be true
    end
  end

  describe "#cancel_reminder" do
    it "rejects invalid params" do
      expect { customer.cancel_reminder(1) }.to raise_error(/Expected String got Integer/)
    end

    it "works" do
      res = await_done(customer.cancel_reminder("test"))
      expect(res).to include(:status, :description, :customer_id)
      expect(res[:status]).to be true
    end
  end

  describe "#get_secondary_ids" do
    it do
      res = await_done(customer.get_secondary_ids)
      expect(res).to be_an(Array)
    end
  end

  describe "#update_secondary_ids" do
    it "rejects invalid secondary_ids param" do
      not_array = 1
      not_array_of_hashes = [1]
      missing_required_key = [{ value: "val", key: "key" }, { value: "val" }]

      expect { customer.update_secondary_ids(not_array) }
        .to raise_error("Invalid secondary_ids type. Expected Array got Integer")

      expect { customer.update_secondary_ids(not_array_of_hashes) }
        .to raise_error("Invalid secondary_ids[0] type. Expected Hash got Integer")

      expect { customer.update_secondary_ids(missing_required_key) }
        .to raise_error("secondary_ids[1] missing one or more required keys. Required keys are: [:key, :value]")
    end

    it "works" do
      secondary_ids = [{ key: "work_email", value: "john.doe@foo.bar" }]
      res = await_done(customer.update_secondary_ids(secondary_ids))
      expect(res).to include(:status, :description, :customer_id)
      expect(res[:status]).to be true
    end
  end

  describe "#delete_secondary_ids" do
    it "rejects invalid secondary_ids param" do
      not_array = 1
      not_array_of_hashes = [1]
      missing_required_key = [{ value: "foo", key: "bar" }, { key: "foo" }]

      expect { customer.delete_secondary_ids(not_array) }
        .to raise_error("Invalid secondary_ids type. Expected Array got Integer")
      expect { customer.delete_secondary_ids(not_array_of_hashes) }
        .to raise_error("Invalid secondary_ids[0] type. Expected Hash got Integer")
      expect { customer.delete_secondary_ids(missing_required_key) }
        .to raise_error("secondary_ids[1] missing one or more required keys. Required keys are: [:key, :value]")
    end

    it "works" do
      secondary_ids = [{ key: "work_email", value: "john.doe@foo.bar" }]
      res = await_done(customer.delete_secondary_ids(secondary_ids))
      expect(res).to include(:status, :description, :customer_id)
      expect(res[:status]).to be true
    end
  end

  describe "#update_metadata" do
    it "needs a hash" do
      expect { customer.update_metadata([]) }.to raise_error("Invalid data type. Expected Hash got Array")
    end

    it do
      meta = { name: "John Doe", role: "admin" }
      res = await_done(customer.update_metadata(meta))
      expect(res).to include(:status, :description, :customer_id)
      expect(res[:status]).to be true
    end
  end

  describe "#get_metadata" do
    it do
      await_done(customer.update_metadata({ name: "No name" }))

      res = await_done(customer.get_metadata)
      expect(res).to be_a Hash
      expect(res["name"]).to eql "No name" # TODO: make Customer#get_metadata to return a Hash with *indifferent access*
    end
  end

  describe "#delete_metadata" do
    it "needs an array" do
      expect { customer.delete_metadata(1) }.to raise_error("Invalid keys type. Expected Array got Integer")
    end

    it "works" do
      res = await_done(customer.delete_metadata([:name]))
      expect(res).to include(:status, :description, :customer_id)
      expect(res[:status]).to be true
    end
  end

  describe "#update_app_data" do
    it "needs a Hash" do
      expect { customer.update_app_data(1) }.to raise_error("Invalid data type. Expected Hash got Integer")
    end

    it "works" do
      app_data = { last_sign_in_ip: "10.10.10.10", last_sign_in_time: Time.now - 100 }
      res = await_done(customer.update_app_data(app_data))
      expect(res).to include(:status, :description, :customer_id)
      expect(res[:status]).to be true
    end
  end

  describe "#lease_app_data" do
    it do
      app_data = { loan_details: { balance: 150, repayment_date: Time.now + 86_400 } }
      await_done(customer.update_app_data(app_data))

      res = await_done(customer.lease_app_data)
      expect(res).to be_a Hash
      expect(res.dig(:value, "loan_details")).to include("balance", "repayment_date") # TODO: HashWithIndifferentAccess
    end
  end

  describe "#delete_app_data" do
    it do
      res = await_done(customer.delete_app_data)
      expect(res).to include(:status, :description, :customer_id)
      expect(res[:status]).to be true
    end
  end

  describe "#update_activity" do
    let(:activity_channel) { { number: "+25411111111", channel: "mobile" } }
    let(:activity) { { session_id: "session_2132", key: "foo" } }

    it "rejects invalid params" do
      activity_channel_without_number = activity_channel.reject { |k| k == :number }
      activity_without_key = activity.reject { |k| k == :key }

      expect { customer.update_activity(activity_channel_without_number, activity) }
        .to raise_error("activity_channel missing one or more required keys. Required keys are: [:number, :channel]")
      expect { customer.update_activity(activity_channel, activity_without_key) }
        .to raise_error("activity missing one or more required keys. Required keys are: [:session_id, :key]")
    end

    it "works" do
      res = await_done(customer.update_activity(activity_channel, activity))
      expect(res).to include(:status, :description, :customer_id)
      expect(res[:status]).to be true
    end
  end
end

# frozen_string_literal: true

RSpec.describe Elarian::Elarian do
  let(:client) { Helpers::EventMachine.get_client(described_class) }

  describe "#generate_new_token" do
    it do
      res = await(client.generate_auth_token)

      expect(res).to include(:token, :lifetime)
    end
  end

  describe "#add_customer_reminder_by_tag" do
    let(:valid_tag) { { key: "loan_status_tag", value: "serial_defaulter" } }
    let(:valid_reminder) { { key: "pay_up_please", remind_at: Time.now + 86_400, payload: "Final reminder" } }

    it "rejects invalid params" do
      tag_not_hash = reminder_not_hash = 1
      tag_missing_value = valid_tag.reject { |k| k == :value }
      reminder_missing_remind_at = valid_reminder.reject { |k| k == :remind_at }
      reminder_with_extraneous_values = valid_reminder.dup.merge(unexpected_key: "foo")

      expect { client.add_customer_reminder_by_tag(tag_not_hash, valid_reminder) }
        .to raise_error("Invalid tag type. Expected Hash got Integer")
      expect { client.add_customer_reminder_by_tag(tag_missing_value, valid_reminder) }
        .to raise_error("tag missing one or more required keys. Required keys are: [:value, :key]")

      expect { client.add_customer_reminder_by_tag(valid_tag, reminder_not_hash) }
        .to raise_error("Invalid reminder type. Expected Hash got Integer")
      expect { client.add_customer_reminder_by_tag(valid_tag, reminder_missing_remind_at) }
        .to raise_error("reminder missing one or more required keys. Required keys are: [:key, :remind_at]")
      expect { client.add_customer_reminder_by_tag(valid_tag, reminder_with_extraneous_values) }
        .to raise_error(
          "Invalid reminder property unexpected_key. Valid keys are: [:key, :remind_at, :interval, :payload]"
        )
    end

    it do
      res = await(client.add_customer_reminder_by_tag(valid_tag, valid_reminder))
      expect(res).to include(:status, :description, :work_id)
      expect(res[:status]).to be true
    end
  end

  describe "#cancel_customer_reminder_by_tag" do
    let(:valid_key) { "pay_up_please" }
    let(:valid_tag) { { key: "loan_status_tag", value: "serial_defaulter" } }

    it "rejects invalid params" do
      key_not_string = tag_not_hash = 1

      expect { client.cancel_customer_reminder_by_tag(key_not_string, valid_tag) }
        .to raise_error("Invalid key type. Expected String got Integer")
      expect { client.cancel_customer_reminder_by_tag(valid_key, tag_not_hash) }
        .to raise_error("Invalid tag type. Expected Hash got Integer")
    end

    it do
      res = await(client.cancel_customer_reminder_by_tag(valid_key, valid_tag))
      expect(res).to include(:status, :description, :work_id)
      expect(res[:status]).to be true
    end
  end

  describe "#send_message_by_tag" do
    let(:valid_tag) { { key: "loan_status_tag", value: "serial_defaulter" } }
    let(:valid_messaging_channel) { { channel: "sms", number: "+25411111111" } }
    let(:valid_message) { { body: { text: "You owe us some money" } } }

    it "rejects invalid params" do
      tag_not_hash = messaging_channel_not_hash = message_not_hash = 1
      messaging_channel_without_number = valid_messaging_channel.reject { |k| k == :number }
      message_without_body = valid_message.reject { |k| k == :body }

      expect { client.send_message_by_tag(tag_not_hash, valid_messaging_channel, valid_message) }
        .to raise_error("Invalid tag type. Expected Hash got Integer")
      expect { client.send_message_by_tag(valid_tag, messaging_channel_not_hash, valid_message) }
        .to raise_error("Invalid messaging_channel type. Expected Hash got Integer")
      expect { client.send_message_by_tag(valid_tag, valid_messaging_channel, message_not_hash) }
        .to raise_error("Invalid message type. Expected Hash got Integer")

      expect { client.send_message_by_tag(valid_tag, valid_messaging_channel, message_without_body) }
        .to raise_error("message missing one or more required keys. Required keys are: [:body]")

      expect { client.send_message_by_tag(valid_tag, messaging_channel_without_number, valid_message) }
        .to raise_error("messaging_channel missing one or more required keys. Required keys are: [:channel, :number]")
    end

    it do
      res = await(client.send_message_by_tag(valid_tag, valid_messaging_channel, valid_message))
      expect(res).to include(:status, :description, :work_id)
      expect(res[:status]).to be true
    end
  end

  describe "#initiate_payment" do
    let(:valid_debit_party) do
      { purse: { purse_id: "purse_123" } }
    end
    let(:valid_credit_party) do
      {
        customer: {
          customer_number: { number: "+25400000000", provider: "cellular" },
          channel_number: { number: "+25411111111", channel: "cellular" }
        }
      }
    end
    let(:valid_value) { { amount: 1000, currency_code: "KES" } }

    it "rejects invalid params" do
      value_without_amount = valid_value.reject { |k| k == :amount }

      expect { client.initiate_payment(1, valid_credit_party, valid_value) }
        .to raise_error("Invalid debit_party type. Expected Hash got Integer")
      expect { client.initiate_payment(valid_debit_party, 1, valid_value) }
        .to raise_error("Invalid credit_party type. Expected Hash got Integer")
      expect { client.initiate_payment(valid_debit_party, valid_credit_party, 1) }
        .to raise_error("Invalid value type. Expected Hash got Integer")
      expect { client.initiate_payment(valid_debit_party, valid_credit_party, value_without_amount) }
        .to raise_error("value missing one or more required keys. Required keys are: [:amount, :currency_code]")
    end

    it "works"
  end
end

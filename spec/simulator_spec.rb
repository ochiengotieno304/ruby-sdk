# frozen_string_literal: true

RSpec.describe Elarian::Simulator do
  let(:simulator) { Helpers::EventMachine.get_client(described_class) }

  describe "#receive_message" do
    let(:params) do
      {
        phone_number: "+25411111111",
        messaging_channel: { channel: "sms", number: "RSDK_SENDER" },
        session_id: "dummy_session_id",
        message_parts: [{ text: "hello" }],
        cost: { amount: 1000, currency_code: "KES" }
      }
    end

    it "rejects invalid params" do
      expect { simulator.receive_message(**params.merge(messaging_channel: 1)) }
        .to raise_error("Invalid messaging_channel type. Expected Hash got Integer")
      expect { simulator.receive_message(**params.merge(messaging_channel: { channel: "sms" })) }
        .to raise_error("messaging_channel missing one or more required keys. Required keys are: [:channel, :number]")
      expect { simulator.receive_message(**params.merge(message_parts: 1)) }
        .to raise_error("Invalid message_parts type. Expected Array got Integer")
      expect { simulator.receive_message(**params.merge(cost: 1)) }
        .to raise_error("Invalid cost type. Expected Hash got Integer")
      expect { simulator.receive_message(**params.merge(cost: {})) }
        .to raise_error("cost missing one or more required keys. Required keys are: [:currency_code, :amount]")
    end

    it "has the expected response" do
      res = await(simulator.receive_message(**params))
      expect(res).to include(:status, :description, :message)
    end
  end

  describe "#receive_payment" do
    let(:params) do
      {
        phone_number: "+25411111111",
        payment_channel: { channel: "cellular", number: "+25411111111" },
        transaction_id: "dummy_transaction_id",
        value: { amount: 1000, currency_code: "KES" },
        status: "success"
      }
    end

    it "rejects invalid params" do
      expect { simulator.receive_payment(**params.merge(payment_channel: 1)) }
        .to raise_error("Invalid payment_channel type. Expected Hash got Integer")
      expect { simulator.receive_payment(**params.merge(payment_channel: {})) }
        .to raise_error("payment_channel missing one or more required keys. Required keys are: [:number, :channel]")
      expect { simulator.receive_payment(**params.merge(value: 1)) }
        .to raise_error("Invalid value type. Expected Hash got Integer")
      expect { simulator.receive_payment(**params.merge(value: { amount: 1000 })) }
        .to raise_error("value missing one or more required keys. Required keys are: [:currency_code, :amount]")
      expect { simulator.receive_payment(**params.merge(status: "dummy")) }.to raise_error(/Invalid key "dummy"/)
    end

    it "has the expected response" do
      res = await(simulator.receive_payment(**params))
      expect(res).to include(:status, :description, :message)
    end
  end

  describe "#update_payment_status" do
    it "rejects invalid payment status" do
      transaction_id = "foo"
      status = "bar"
      expect { simulator.update_payment_status(transaction_id, status) }.to raise_error(/Invalid key "bar"/)
    end

    it "has the expected response" do
      transaction_id = "some_id"
      res = await(simulator.update_payment_status(transaction_id, status))
      expect(res).to include(:status, :description, :message)
    end
  end
end

# frozen_string_literal: true

require "elarian"

creds = {
  api_key: ENV["API_KEY"],
  org_id: ENV["ORG_ID"],
  app_id: ENV["APP_ID"]
}

@client = Elarian::Client.new(**creds)
@customer = Elarian::Customer.new(client: @client, number: "254712345678")
def observer(next_action = nil)
  Rx::Observer.configure do |obs|
    obs.on_next do |payload|
      p payload
      next_action&.call
    end
    obs.on_error { |e| puts "ERROR: #{e}" }
  end
end

def get_state
  puts "\n\ngetting state"
  @customer.get_state
end

def add_reminder
  puts "\n\nadding reminder"
  @customer.add_reminder({ key: "EAT",
                           payload: "Eat healthy please or die",
                           remind_at: Time.now - 15 })
end

def cancel_reminder
  puts "\n\ncancelling reminder"
  @customer.cancel_reminder("EAT")
end

def get_secondary_ids
  puts "\n\nGetting secondary ids"
  @customer.get_secondary_ids
end

def update_secondary_ids
  puts "\n\nUpdating secondary ids"
  @customer.update_secondary_ids(
    [
      {
        key: "passport_number",
        value: "404041",
        expires_at: Time.now + 1e5
      }
    ]
  )
end

def delete_secondary_ids
  puts "\n\nDeleting customer ids"
  @customer.delete_secondary_ids([{ key: "national_id_card", value: "404040" }])
end

def update_metadata
  puts "\n\nUpdating metadata"
  @customer.update_metadata({ age_group: "100 - infinity", mood: "😅" })
end

def delete_metadata
  puts "\n\nDeleting metadata"
  @customer.delete_metadata(["nonexist"])
end

def update_app_data
  puts "\n\nUpdating App Data"
  app_data = {
    pets: [
      { name: "Snowflake", type: "Cat", sub_type: "Siamese", vaccination_records: [] },
      { name: "Zeus", type: "Dog", sub_type: "Great Dane", vaccination_records: [
        # {date: Date.today - 5.months, vaccine: "DHPP, rabies"},
        # {date: Date.today - (11.months + 5.days), vaccine: "Distemper, parvovirus"}
      ] }
    ]
  }
  @customer.update_app_data(app_data)
end

def lease_app_data
  puts "\n\nLeasing App Data"
  @customer.lease_app_data
end

def delete_app_data
  puts "\n\nDeleting App Data"
  @customer.delete_app_data
end

def get_metadata
  puts "\n\nGetting Metadata"
  @customer.get_metadata
end

def get_tags
  puts "\n\nGetting tags"
  @customer.get_tags
end

def update_tags
  puts "\n\n Updating tags"
  @customer.update_tags([{ key: "Loyalty Group", value: "Super-Duper-Loyal", expires_at: (Time.now + 1000).to_i }])
end

def delete_tags
  puts "\n\n Deleting tags"
  @customer.delete_tags(["Loyalty Group"])
end

def update_activity
  puts "\n\n Updating Activity"
  activity_channel = { number: "num_channel", channel: "web" }
  activity = { session_id: "some_fake_session_id", key: "the_fake_key" }
  @customer.update_activity(activity_channel, activity)
end

def send_message
  puts "\n\nSending Message"
  message = {
    body: {
      email: { subject: "Greetings", plain: "How are you doing?" }
    }
  }
  messaging_channel = { number: "1", channel: "email" }
  @customer.send_message(messaging_channel, message)
end

def send_message_email
  puts "\n\nSending Email"
  message = {
    body: {
      # email: {subject: "Greetings", plain: "How are you doing?"}
    }
  }
  messaging_channel = { number: "someone@domain.fake", channel: "email" }
  @customer.send_message(messaging_channel, message)
end

def send_message_text
  messaging_channel = { number: "+254723045945", channel: "sms" }
  message = { body: { text: "Yooooooo! How's it going??" } }
  @customer.send_message(messaging_channel, message)
end

def send_message_ussd
  messaging_channel = { number: "+254723045945", channel: "ussd" }
  message = { body: { ussd: { text: "What do you want to do", is_terminal: false } } }
  @customer.send_message(messaging_channel, message)
end

def send_message_media
  message = {
    body: {
      media: {
        type: "image",
        url: "https://i.picsum.photos/id/533/200/300.jpg?hmac=eehg5zb3wyJViBC8IiDL85fqqk9z85uHtRciYvDovgA"
      }
    }
  }
  messaging_channel = { number: "bla", channel: "telegram" }
  @customer.send_message(messaging_channel, message)
end

def send_message_location
  message = {
    body: {
      location: {
        latitude: -59.21088,
        longitude: 16.56753,
        label: "SOme random place"
      }
    }
  }
  messaging_channel = { number: "bla", channel: "telegram" }
  @customer.send_message(messaging_channel, message)
end

def send_message_template
  message = { body: { template: { id: "my_superb_template" } } }
  messaging_channel = { number: "bla", channel: "telegram" }
  @customer.send_message(messaging_channel, message)
end

def send_message_voice
  message = {
    body: {
      voice: [
        get_digits: {
          say: { text: "Hello hello" },
          num_digits: 5,
          finish_on_key: "9",
          timeout: 400
        }
      ]
    }
  }
  messaging_channel = { number: "bla", channel: "voice" }
  @customer.send_message(messaging_channel, message)
end

def send_message_url; end

def reply_to_message
  puts "\n\nReplying to message"
  message = {
    body: {
      voice: [
        get_digits: {
          say: { text: "Hello hello" },
          num_digits: 5,
          finish_on_key: "9",
          timeout: 400
        }
      ]
    }
  }
  cust = Elarian::Customer.new(id: "el_cst_aadd0e3e92faa0d6499624ac2c86d63b", client: @client)
  cust.reply_to_message("111", message)
end

def do_3(*actions)
  raise "Expected 3 got #{actions.length}" unless actions.length == 3

  a, b, c = actions
  method(a).call.subscribe(observer(lambda {
    method(b).call.subscribe(observer(lambda {
      method(c).call.subscribe(observer)
    }))
  }))
end
on_connected = lambda do
  do_3(:send_message_voice, :update_metadata, :delete_metadata)
end
@client.on("connected", on_connected)
begin
  EM.run do
    @client.connect
  end
rescue SystemExit, Interrupt
  puts "\nBYE"
end

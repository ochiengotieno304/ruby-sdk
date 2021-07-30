# frozen_string_literal: true

require "elarian"

@sms_channel = { number: ENV["SMS_SHORT_CODE"], channel: "SMS" }

@voice_channel = { number: ENV["VOICE_NUMBER"], channel: "VOICE" }

@mpesa_channel = {
  number: ENV["MPESA_PAYBILL"],
  channel: "CELLULAR"
}

@purse_id = ENV["PURSE_ID"]

@client = Elarian::Elarian.new(
  org_id: ENV["ORG_ID"],
  app_id: ENV["APP_ID"],
  api_key: ENV["API_KEY"]
)

def approve_loan(customer, amount)
  puts "Approving loan for #{cusomer.customer_number[:number]}"
  customer.get_metadata
          .flat_map do |meta|
            name = meta.fetch("name", "Unknown Customer")
            repayment_date = Time.now + 60

            init_payment = @client.iniate_payment(
              debit_party: { purse: { purse_id: @purse_id } },
              credit_party: { customer: { channel_number: @mpesa_channel, customer_number: customer.customer_number } },
              value: { amount: amount, currency_code: "KES" }
            )
            confirmation = init_payment.flat_map do |res|
              raise "Failed to make loan payment: #{res}" unless %i[SUCCESS PENDING_CONFIRMATION].include?(res[:status])
            end
            confirmation.flat_map { customer.update_metadata({ name: name, balance: amount }) }
                        .flat_map do
                          message = "Congratulations #{name}!\nYour loan of KES #{amount}
                                    has been approved!\nYou are expected to pay it back by
                                    #{repayment_date}"
                          customer.send_message(@sms_channel, { body: { text: message } })
                        end
            confirmation.flat_map { customer.add_reminder({ key: "moni", remind_at: repayment_date, payload: "" }) }
          end
          .subscribe(
            ->(_res) { puts "Successfully Approved loan for #{customer.customer_number}" },
            ->(err) { puts "Failed to approve loan: #{err}" },
            -> {}
          )
end

def handle_payment(notification, customer, _app_data, _callback)
  puts "Processing payment from #{notification[:customer_number][:number]}"
  customer.get_metadata
          .flat_map do |meta|
            meta = {} if meta.nil?
            amount = notification[:value][:amount]
            name = meta.fetch("name", "Unknown Customer")
            balance = meta.fetch("balance", 0).to_f

            new_balance = balance - amount
            customer.update_metadata({ "name": name, "balance": new_balance })
                    .flat_map do
                      if new_balance.negative?
                        text = "Thank you for your payment #{name}, your loan has been fully repaid!!"
                        customer.cancel_reminder("moni")
                                .flat_map { customer.delete_metadata(%w[name strike balance screen]) }
                      else
                        text = "Hey #{name}!\nThank you for your payment, but you still owe me KES #{new_balance}"
                      end
                      customer.send_message(@sms_channel, { body: { text: text } })
                    end
          end
          .subscribe(
            ->(_res) { puts "Successfully Processed payment from #{notification[:customer_number][:number]}" },
            ->(err) { puts "Failed to process payment: #{err}" },
            -> {}
          )
end

def handle_ussd(notification, customer, _app_data, _callback)
  puts "Processing ussd from #{notification[:customer_number][:number]}"
  ussd_input = notification[:input][:text]
  screen = app_data.fetch(:screen, "home")

  customer.get_metadata
          .flat_map do |meta|
            name = meta["name"]
            balance = meta.fetch("balance", 0)
            menu = { text: nil, is_terminal: false }

            next_screen = screen
            if screen == "home" && ussd_input != ""
              case ussd_input
              when "1"
                next_screen = "request-name"
              when "2"
                next_screen = "quit"
              end
            end

            next_screen = "info" unless name.nil? && screen == "home" && ussd_input == ""
            case next_screen
            when "quit"
              menu["text"] = "Happy Coding!"
              menu["is_terminal"] = true
              next_screen = "home"
              yield({ body: { ussd: menu } }, { screen: next_screen })
            when "info"
              menu["text"] = if balance.positive?
                               "Hey #{name} you still owe me KES #{balance}"
                             else
                               "Hey #{name} you have repaid your loan, good for you!"
                             end
              menu["is_terminal"] = true
              next_screen = "home"
              yield({ body: { ussd: menu } }, { screen: next_screen })
            when "request-name"
              menu["text"] = "Alright, what is your name?"
              next_screen = "request-amount"
              yield({ body: { ussd: menu } }, { screen: next_screen })
            when "request-amount"
              name = ussd_input
              menu["text"] = "Okay #{name}, how much do you need?"
              next_screen = "approve-amount"
              yield({ body: { ussd: menu } }, { screen: next_screen })
            when "approve-amount"
              balance = ussd_input.to_f
              menu["text"] = "Awesome! #{name} we are reviewing your application
                              and will be in touch shortly!\nHave a lovely day!"
              menu["is_terminal"] = true
              next_screen = "home"
              yield({ body: { ussd: menu } }, { screen: next_screen })
              @client.approve_loan(customer, balance)
            when "home"
              menu["text"] = "Welcome to MoniMoni!\n1. Apply for loan\n2. Quit"
              menu["is_terminal"] = false
              yield({ body: { ussd: menu } }, { screen: next_screen })
            end

            customer.update_metadata({ name: name, balance: amount })
          end
          .subscribe(
            ->(_res) { puts "Successfully Processed ussd request from #{notification[:customer_number][:number]}" },
            ->(err) { puts "Failed to process ussd: #{err}" },
            -> {}
          )
end

def handle_reminder(_notification, customer, _app_data, _callback)
  puts "Processing Reminder"
  customer.get_metadata
          .flat_map do |meta|
            name = meta.fetch(:name, "Unknown Customer")
            balance = meta.fetch(:balance, 0).to_f
            strike = meta.fetch(:strike, 1)

            channel = @sms_channel
            message = {
              body: { text: "Hello #{name}, this is a friendly reminder to pay back my KES #{balance}" }
            }
            if strike == 2
              message[:body][:text] = "Hey #{name}, you still need to pay back my KES #{balance}"
            elsif strike > 2
              channel = @voice_channel
              message[:body] = {
                voice: [{ say: { text: "Yo #{name}! You need to pay back my KES #{balance}", voice: "male" } }]
              }
            end

            meta[:strike] = strike + 1
            reminder = { key: "moni", remind_at: Time.now + 60, payload: "" }
            customer.update_metadata(meta)
                    .flat_map { customer.add_reminder(reminder) }
                    .flat_map { customer.send_message(channel, message) }
          end
          .subscribe(
            ->(_res) { puts "Successfully Processed Reminder" },
            ->(err) { puts "Failed to process reminder: #{err}" },
            -> {}
          )
end

@client.on("connected", -> { puts "App is connected, waiting for customers on #{ENV["USSD_CODE"]}" })
@client.on("closed", -> { puts "Connection Closed" })
@client.on("received_payment", ->(*args, &blk) { handle_payment(*args, blk) })
@client.on("received_sms", ->(*args, &blk) { handle_sms(*args, blk) })
@client.on("reminder", ->(*args, &blk) { handle_reminder(*args, blk) })
@client.on("ussd_session", ->(*args, &blk) { handle_ussd(*args, blk) })

at_exit do
  @client.disconnect
  EventMachine.stop
end

EventMachine.run do
  @client.connect

  Signal.trap("INT") do
    @client.disconnect
    EventMachine.stop
  end

  Signal.trap("TERM") do
    @client.disconnect
    EventMachine.stop
  end
end

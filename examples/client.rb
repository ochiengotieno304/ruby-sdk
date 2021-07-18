# frozen_string_literal: true

require "elarian"

def client
  api_key = ENV["API_KEY"]
  org_id = ENV["ORG_ID"]
  app_id = ENV["APP_ID"]
  @client ||= Elarian::Client.new(api_key: api_key, org_id: org_id, app_id: app_id)
end


client.on('connected', -> (){ 
  customer = Elarian::Customer.new(client: client, number: "254709759881")
  customer.get_state.subscribe(Rx::Observer.configure do |observer|
      observer.on_next { |payload| puts payload }
      observer.on_completed { puts "Get customer state completed" }
      observer.on_error { |error| puts error }
    end)
 })

EventMachine.run do
  puts "starting"
  client.connect
end

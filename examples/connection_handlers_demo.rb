# frozen_string_literal: true

# Temporary example. Demo of how users would register connection handlers i.e. 'pending', 'connecting', 'connected' etc.

require "elarian"

def client
  creds = {
    api_key: ENV["API_KEY"],
    org_id: ENV["ORG_ID"],
    app_id: ENV["APP_ID"]
  }
  @client ||= Elarian::Client.new(**creds)
end

def connection_pending
  puts "connection is pending"
end

def connecting
  puts "trying to connect now..."
end

def connected
  puts "We are now connected!"
end

def closed
  puts "connection closed"
end

client.on("pending", -> { connection_pending })
client.on("connecting", -> { connecting })
client.on("connected", -> { connected })
client.on("closed", -> { closed })

EM.run do
  client.connect
  EM::Timer.new(15) do
    # close connection after 15 seconds so that we can check whether on_closed handler is called
    client.disconnect
  end
end

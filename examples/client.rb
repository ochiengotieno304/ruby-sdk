# frozen_string_literal: true

require "elarian"

def client
  api_key = ENV["API_KEY"]
  org_id = ENV["ORG_ID"]
  app_id = ENV["APP_ID"]
  Elarian::Client.new(api_key: api_key, org_id: org_id, app_id: app_id)
end

EventMachine.run do
  puts "starting"
  rsocket = client.connect

  req = Com::Elarian::Hera::Proto::AppToServerCommand.new(
    get_customer_state: Com::Elarian::Hera::Proto::GetCustomerStateCommand.new(
      customer_number: Com::Elarian::Hera::Proto::CustomerNumber.new(
        provider: Com::Elarian::Hera::Proto::CustomerNumberProvider::CUSTOMER_NUMBER_PROVIDER_CELLULAR,
        number: "+254709759881"
      ),
      customer_id: "el_cst_wrong_cust_id"
    )
  )
  rsocket.request_response(payload_of(req.to_proto, nil))
         .subscribe(Rx::Observer.configure do |observer|
                      observer.on_next { |payload| puts payload }
                      observer.on_completed { puts "completed" }
                      observer.on_error { |error| puts error }
                    end)
end

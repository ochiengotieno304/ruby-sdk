# Elarian Ruby SDK

>
>
> A convenient way to interact with the Elarian APIs.
>
> **Project Status: Still under ACTIVE DEVELOPMENT, APIs are unstable and may change at any time until release of v1.0.0.**

## Install

Add this line to your application's Gemfile:

```ruby
gem 'elarian'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install elarian

## Usage

```ruby
require 'elarian'

api_key = "test_api_key"
org_id = "test_org_id"
app_id = "test_app_id"
@client = Elarian::Client.new(api_key: api_key, org_id: org_id, app_id: app_id)
@customer = Elarian::Customer.new(client: @client, number: "254709759881")

EventMachine.run do
  puts "starting"
  @client.connect

  messaging_channel = { number: "+254723456789", channel: "sms" }
  message = { body: { text: "Yooooooo! How's it going??" } }
  @customer.send_message(messaging_channel, message)
end
```


See [examples](examples) for more usage examples.

## Issues

If you find a bug, please file an issue on [our issue tracker on GitHub](https://github.com/ElarianLtd/ruby-sdk/issues).

# Elarian

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/elarian`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'elarian'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install elarian

## Usage

The library needs to be instantiated with your client_id and client_secret. This returns a client object that is authenticated with Oauth2.

```ruby
require "elarian"
elarian = Elarian::Client.new(api_key: "test_api_key", org_id: "test_org", app_id: "test_app_id")
customer = Elarian::Customer.new(client: elarian, number: "+254709759881")

elarian.await.connect

# get customer state
resp = customer.await.get_state

puts(resp)
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/elarian/ruby-sdk. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/elarian/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Elarian project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/elarian/ruby-sdk/blob/master/CODE_OF_CONDUCT.md).

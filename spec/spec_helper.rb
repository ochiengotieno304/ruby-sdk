# frozen_string_literal: true

require "elarian"

require_relative "support/helpers/elarian"
require_relative "support/helpers/event_machine"
require_relative "support/helpers/callable"
require_relative "support/helpers/rx"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) { Helpers::EventMachine.start_em_loop }
  config.after(:suite) { Helpers::EventMachine.disconnect_and_stop_loop }

  config.include Helpers::Elarian
  config.include Helpers::EventHandler
  config.include Helpers::Rx
end

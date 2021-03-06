# frozen_string_literal: true

require_relative "lib/elarian/ruby/version"

Gem::Specification.new do |spec|
  spec.name          = "elarian"
  spec.version       = Elarian::VERSION
  spec.authors       = ["Hannah Masila"]
  spec.email         = ["hannahmasila@gmail.com"]

  spec.summary       = "A convenient way to interact with the Elarian APIs."
  spec.description   = "A convenient way to interact with the Elarian APIs."
  spec.homepage      = "https://developers.elarian.com/"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.4.0")

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ElarianLtd/ruby-sdk"
  spec.metadata["changelog_uri"] = "https://github.com/ElarianLtd/ruby-sdk/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z --recurse-submodules`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # dependencies used by rsocket-rb
  spec.add_dependency "eventmachine", "~> 1.2.7"
  spec.add_dependency "rx", "~> 0.0.3"

  spec.add_dependency "google-protobuf", "~> 3.17"

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end

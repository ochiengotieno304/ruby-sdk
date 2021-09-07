# frozen_string_literal: true

custom_paths = [
  # rsocket
  File.expand_path("../../rsocket-rb/lib", __dir__),

  # compiled proto files
  File.expand_path("service", __dir__)
]

custom_paths.each { |path| $LOAD_PATH.unshift(path) unless $LOAD_PATH.include? path }

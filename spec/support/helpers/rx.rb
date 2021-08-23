# frozen_string_literal: true

module Helpers
  module Rx
    def await(async_subject)
      done = false
      res = nil

      observable = async_subject.as_observable
      observable.subscribe_on_next { |payload| res = payload }
      observable.subscribe_on_completed { done = true }
      observable.subscribe_on_error do |err|
        done = true
        raise err
      end

      until done; end
      res
    end
  end
end

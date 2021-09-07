# frozen_string_literal: true

module Helpers
  module Elarian
    def connection_credentials
      { api_key: ENV["API_KEY"], org_id: ENV["ORG_ID"], app_id: ENV["APP_ID"] }
    end
  end
end

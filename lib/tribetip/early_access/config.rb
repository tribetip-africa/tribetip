# frozen_string_literal: true

module Tribetip
  module EarlyAccess
    module Config
      module_function

      def invite_ttl_days
        ENV.fetch("TRIBETIP_EARLY_ACCESS_INVITE_TTL_DAYS", "14").to_i
      end
    end
  end
end

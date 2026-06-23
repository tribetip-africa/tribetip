# frozen_string_literal: true

module Tribetip
  module Security
    module FreshSession
      module_function

      def max_age
        ENV.fetch("TRIBETIP_FRESH_SESSION_SECONDS", 15.minutes.to_i).to_i.seconds
      end

      def satisfied_by?(tribe)
        return false unless tribe

        authenticated_at = tribe.last_password_authenticated_at
        authenticated_at.present? && authenticated_at >= max_age.ago
      end
    end
  end
end

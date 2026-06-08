# frozen_string_literal: true

module Tribetip
  module Errors
    class OnboardingRequired < Base
      private

      def default_code
        "onboarding_required"
      end

      def default_http_status
        :forbidden
      end

      def default_message
        "Complete Paystack setup before accessing the dashboard."
      end
    end
  end
end

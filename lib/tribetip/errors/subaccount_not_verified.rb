# frozen_string_literal: true

module Tribetip
  module Errors
    class SubaccountNotVerified < Base
      private

      def default_code
        "subaccount_not_verified"
      end

      def default_http_status
        :forbidden
      end

      def default_message
        "Paystack must verify your payout account before you can publish your page."
      end
    end
  end
end

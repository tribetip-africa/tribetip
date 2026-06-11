# frozen_string_literal: true

module Tribetip
  module Paystack
    module WithdrawalErrors
      STARTER_BUSINESS_PATTERNS = [
        /third[- ]party payouts/i,
        /starter business/i
      ].freeze

      module_function

      def starter_business?(message)
        text = message.to_s
        return false if text.blank?

        STARTER_BUSINESS_PATTERNS.any? { |pattern| text.match?(pattern) }
      end

      def friendly_message(message)
        return default_message if message.blank?

        if starter_business?(message)
          return "Manual withdrawals require a Paystack Registered Business account with Transfers enabled. " \
                 "Tips will settle automatically until your Paystack account is upgraded."
        end

        message
      end

      def default_message
        "Unable to initiate withdrawal with Paystack."
      end
    end
  end
end

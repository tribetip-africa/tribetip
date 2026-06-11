# frozen_string_literal: true

module Tribetip
  module Paystack
    module PlatformFee
      module_function

      def percent
        ENV.fetch("PAYSTACK_PLATFORM_FEE_PERCENT", "5").to_f
      end

      def net_cents(gross_cents)
        (gross_cents.to_i * (100.0 - percent) / 100.0).floor
      end

      def fee_cents(gross_cents, net_cents:)
        gross_cents.to_i - net_cents.to_i
      end
    end
  end
end

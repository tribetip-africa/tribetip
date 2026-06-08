# frozen_string_literal: true

module Tribetip
  module Audit
    class StoreVerificationSnapshot
      def self.call(tip:, source:, verification:, success:, message: nil, paystack_event: nil)
        snapshot = {
          "status" => verification.status,
          "subaccount_code" => verification.subaccount_code,
          "verified_at" => Time.current.iso8601(3),
          "source" => source.to_s,
          "success" => success,
          "message" => message
        }.compact

        metadata = tip.paystack_metadata.merge("last_verification" => snapshot)
        attrs = { paystack_metadata: metadata }
        attrs[:last_paystack_event_id] = paystack_event.id if paystack_event

        tip.update!(attrs)
        snapshot
      end
    end
  end
end

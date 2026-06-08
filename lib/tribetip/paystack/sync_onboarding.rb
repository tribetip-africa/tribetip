# frozen_string_literal: true

module Tribetip
  module Paystack
    class SyncOnboarding
      Status = Struct.new(
        :customer_ready,
        :subaccount_ready,
        :complete,
        :verification,
        :provisioning_error,
        keyword_init: true
      ) do
        def as_json(*)
          {
            customer_ready: customer_ready,
            subaccount_ready: subaccount_ready,
            complete: complete,
            verification: verification,
            provisioning_error: provisioning_error
          }.compact
        end
      end

      def self.call(tribe)
        new(tribe).call
      end

      def initialize(tribe)
        @tribe = tribe
      end

      def call
        report = AuditOnboarding.call(@tribe.reload, sync: true)

        Status.new(
          customer_ready: @tribe.paystack_customer_ready?,
          subaccount_ready: @tribe.paystack_subaccount_ready?,
          complete: report.onboarding_complete,
          verification: report.checks.map(&:as_json),
          provisioning_error: @tribe.paystack_provisioning_error
        )
      end
    end
  end
end

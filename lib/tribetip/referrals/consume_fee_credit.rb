# frozen_string_literal: true

module Tribetip
  module Referrals
    class ConsumeFeeCredit
      Result = Struct.new(:applied_cents, keyword_init: true)

      def self.call(tip)
        new(tip).call
      end

      def initialize(tip)
        @tip = tip
      end

      def call
        return Result.new(applied_cents: 0) unless Config.enabled?
        return Result.new(applied_cents: 0) unless @tip.paid?

        tribe = @tip.tribe
        return Result.new(applied_cents: 0) if tribe.referral_fee_credit_cents_remaining <= 0

        gross_cents = @tip.amount_cents
        net_cents = Paystack::PlatformFee.net_cents(gross_cents)
        fee_cents = Paystack::PlatformFee.fee_cents(gross_cents, net_cents: net_cents)
        applied = [ tribe.referral_fee_credit_cents_remaining, fee_cents ].min
        return Result.new(applied_cents: 0) if applied <= 0

        tribe.with_lock do
          tribe.reload
          applied_locked = [ tribe.referral_fee_credit_cents_remaining, fee_cents ].min
          if applied_locked <= 0
            Result.new(applied_cents: 0)
          else
            tribe.update!(
              referral_fee_credit_cents_remaining: tribe.referral_fee_credit_cents_remaining - applied_locked
            )

            @tip.update!(
              paystack_metadata: @tip.paystack_metadata.merge(
                "referral_fee_credit_applied_cents" => applied_locked
              )
            )

            Result.new(applied_cents: applied_locked)
          end
        end
      end
    end
  end
end

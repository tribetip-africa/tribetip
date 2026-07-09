# frozen_string_literal: true

module Tribetip
  module Referrals
    class Qualify
      Result = Struct.new(:qualified?, :referral, :reason, keyword_init: true)

      def self.call(tip)
        new(tip).call
      end

      def initialize(tip)
        @tip = tip
      end

      def call
        return skip("referrals_disabled") unless Config.enabled?
        return skip("tip_not_paid") unless @tip.paid?

        referral = Referral.pending.find_by(referred: @tip.tribe)
        return skip("no_pending_referral") unless referral

        tribe = @tip.tribe
        return skip("onboarding_incomplete") unless tribe.paystack_onboarding_complete?
        return skip("not_first_paid_tip") unless first_paid_tip?(tribe)
        return skip("tip_below_minimum") if @tip.amount_cents < Config.min_qualification_tip_cents(@tip.currency)

        fraud_reason = FraudCheck.qualification_block_reason(referral)
        if fraud_reason.present?
          Reject.call(
            referral,
            reason: fraud_reason,
            actor_id: nil,
            metadata: { auto_rejected: true, rejected_stage: "qualification" }
          )
          return skip(fraud_reason)
        end

        referral.with_lock do
          referral.reload
          return skip("referral_no_longer_pending") unless referral.pending?

          referral.update!(
            status: "qualified",
            qualified_at: Time.current,
            qualifying_tip: @tip,
            metadata: referral.metadata.merge(
              "qualifying_tip_id" => @tip.id,
              "qualified_at" => Time.current.iso8601
            )
          )
        end

        grant_referred_fee_credit!(tribe)
        RecordNotification.referrer_qualified(referral)
        RecordNotification.referred_qualified(referral)
        ::Referrals::IssueReferrerBonusJob.perform_later(referral.id)

        Result.new(qualified?: true, referral: referral.reload)
      end

      private

      def first_paid_tip?(tribe)
        tribe.tips.paid.order(:paid_at, :created_at).limit(1).pick(:id) == @tip.id
      end

      def grant_referred_fee_credit!(tribe)
        credit = Config.referred_fee_credit_cents(tribe.currency)
        return if credit <= 0

        tribe.with_lock do
          tribe.reload
          tribe.update!(
            referral_fee_credit_cents_remaining: tribe.referral_fee_credit_cents_remaining + credit
          )
        end
      end

      def skip(reason)
        Result.new(qualified?: false, reason: reason)
      end
    end
  end
end

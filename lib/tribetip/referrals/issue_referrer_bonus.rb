# frozen_string_literal: true

module Tribetip
  module Referrals
    class IssueReferrerBonus
      Result = Struct.new(:success?, :referral, :message, keyword_init: true)

      def self.call(referral)
        new(referral).call
      end

      def initialize(referral)
        @referral = referral
        @client = Paystack::Client.new
      end

      def call
        return skip("referrals_disabled") unless Config.enabled?
        return skip("already_rewarded") if @referral.rewarded_at.present?
        return skip("not_qualified") unless @referral.status == "qualified"

        referrer = @referral.referrer
        amount_cents = Config.referrer_bonus_cents(referrer.currency)
        return skip("bonus_disabled") if amount_cents <= 0
        return skip("referrer_payout_not_ready") unless referrer.paystack_payout_linked?

        fraud_reason = FraudCheck.reward_block_reason(@referral)
        if fraud_reason.present?
          Reject.call(
            @referral,
            reason: fraud_reason,
            actor_id: nil,
            metadata: { auto_rejected: true, rejected_stage: "reward" }
          )
          return skip(fraud_reason)
        end

        reference = "refbonus_#{@referral.id}"
        transfer = @client.initiate_subaccount_withdrawal(
          subaccount: referrer.paystack_subaccount_code,
          amount_cents: amount_cents,
          currency: referrer.currency,
          reference: reference,
          reason: "TribeTip referral bonus",
          metadata: {
            referral_id: @referral.id,
            referred_username: @referral.referred.username,
            referrer_username: referrer.username,
            source: "referral_bonus"
          }
        )

        unless transfer.success?
          @referral.update!(
            metadata: @referral.metadata.merge(
              "referrer_bonus_error" => transfer.message,
              "referrer_bonus_attempted_at" => Time.current.iso8601
            )
          )
          return Result.new(success?: false, referral: @referral, message: transfer.message)
        end

        @referral.with_lock do
          @referral.reload
          return skip("already_rewarded") if @referral.rewarded_at.present?

          @referral.update!(
            status: "rewarded",
            rewarded_at: Time.current,
            referrer_bonus_cents: amount_cents,
            referrer_bonus_currency: referrer.currency,
            referrer_bonus_reference: reference,
            referrer_bonus_transfer_code: transfer.transfer_code,
            metadata: @referral.metadata.merge(
              "referrer_bonus_paid_at" => Time.current.iso8601,
              "referrer_bonus_transfer_code" => transfer.transfer_code
            )
          )
        end

        RecordNotification.referrer_bonus_paid(@referral.reload)
        Result.new(success?: true, referral: @referral, message: "Referral bonus sent.")
      end

      private

      def skip(message)
        Result.new(success?: false, referral: @referral, message: message)
      end
    end
  end
end

# frozen_string_literal: true

module Tribetip
  module Referrals
    class RecordNotification
      class << self
        def referrer_qualified(referral)
          create_once!(
            tribe: referral.referrer,
            kind: "referral_qualified",
            title: "Referral qualified",
            body: "@#{referral.referred.username} completed onboarding and received a first tip.",
            metadata: referral_metadata(referral)
          )
        end

        def referred_qualified(referral)
          credit = format_amount(
            referral.referred.referral_fee_credit_cents_remaining,
            referral.referred.currency
          )

          create_once!(
            tribe: referral.referred,
            kind: "referral_welcome_bonus",
            title: "Welcome bonus active",
            body: "Your referral welcome bonus is active. #{credit} in fee credits will apply to your tips.",
            metadata: referral_metadata(referral).merge(
              referral_fee_credit_cents_remaining: referral.referred.referral_fee_credit_cents_remaining
            )
          )
        end

        def referrer_bonus_paid(referral)
          amount = format_amount(referral.referrer_bonus_cents, referral.referrer_bonus_currency)

          create_once!(
            tribe: referral.referrer,
            kind: "referral_bonus_paid",
            title: "Referral bonus sent",
            body: "#{amount} was sent for referring @#{referral.referred.username}.",
            metadata: referral_metadata(referral).merge(
              referrer_bonus_cents: referral.referrer_bonus_cents,
              referrer_bonus_currency: referral.referrer_bonus_currency,
              referrer_bonus_transfer_code: referral.referrer_bonus_transfer_code
            )
          )
        end

        private

        def create_once!(tribe:, kind:, title:, body:, metadata:)
          return if tribe.creator_notifications.where(kind: kind).where(
            "metadata->>'referral_id' = ?",
            metadata[:referral_id].to_s
          ).exists?

          tribe.creator_notifications.create!(
            kind: kind,
            title: title,
            body: body,
            metadata: metadata
          )
        end

        def referral_metadata(referral)
          {
            referral_id: referral.id,
            referred_username: referral.referred.username,
            referrer_username: referral.referrer.username,
            qualified_at: referral.qualified_at&.iso8601
          }.compact
        end

        def format_amount(cents, currency)
          MoneyFormat.format_cents(cents, currency)
        end
      end
    end
  end
end

# frozen_string_literal: true

module Tribetip
  module Referrals
    class BuildSummary
      def self.call(tribe)
        new(tribe).call
      end

      def initialize(tribe)
        @tribe = tribe
      end

      def call
        counts = Referral.where(referrer: @tribe).group(:status).count
        referrals = Referral.where(referrer: @tribe).order(created_at: :desc)

        {
          referrals_enabled: @tribe.referrals_enabled?,
          program_enabled: Config.enabled?,
          link: link_payload,
          can_refer: Referrals.eligible_referrer?(@tribe),
          stats: {
            pending: counts.fetch("pending", 0),
            qualified: counts.fetch("qualified", 0),
            rewarded: counts.fetch("rewarded", 0),
            rejected: counts.fetch("rejected", 0),
            total: referrals.count
          },
          qualification: {
            requires_onboarding: true,
            requires_first_paid_tip: true,
            min_tip_cents: Config.min_qualification_tip_cents(@tribe.currency),
            referrer_bonus_cents: Config.referrer_bonus_cents(@tribe.currency),
            referred_fee_credit_cents: Config.referred_fee_credit_cents(@tribe.currency),
            currency: @tribe.currency
          },
          fee_credit_cents_remaining: @tribe.referral_fee_credit_cents_remaining,
          entries: referrals.limit(50).map { |referral| entry_payload(referral) }
        }
      end

      private

      def link_payload
        unless @tribe.referrals_enabled?
          return {
            code: nil,
            path: nil,
            url: nil,
            expires_at: nil,
            kind: "invite",
            username_code: @tribe.username
          }
        end

        invite = Invites.ensure_active!(@tribe)
        Invites.payload_for(invite).merge(
          username_code: @tribe.username
        )
      end

      def entry_payload(referral)
        {
          username: referral.referred.username,
          status: referral.status,
          signed_up_at: referral.created_at.iso8601,
          qualified_at: referral.qualified_at&.iso8601,
          rewarded_at: referral.rewarded_at&.iso8601
        }
      end
    end
  end
end

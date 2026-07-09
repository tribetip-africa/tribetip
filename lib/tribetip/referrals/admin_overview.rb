# frozen_string_literal: true

module Tribetip
  module Referrals
    class AdminOverview
      def self.call(limit: 50, offset: 0)
        new(limit: limit, offset: offset).call
      end

      def initialize(limit:, offset:)
        @limit = limit
        @offset = offset
      end

      def call
        scope = Referral.includes(:referrer, :referred, :qualifying_tip).order(created_at: :desc)
        counts = Referral.group(:status).count
        rewarded = Referral.rewarded.where.not(referrer_bonus_cents: nil)

        {
          overview: {
            pending: counts.fetch("pending", 0),
            qualified: counts.fetch("qualified", 0),
            rewarded: counts.fetch("rewarded", 0),
            rejected: counts.fetch("rejected", 0),
            total: Referral.count,
            bonus_paid_cents: rewarded.group(:referrer_bonus_currency).sum(:referrer_bonus_cents)
          },
          referrals: scope.limit(@limit).offset(@offset).map { |referral| entry_json(referral) },
          pagination: {
            limit: @limit,
            offset: @offset,
            total: Referral.count
          }
        }
      end

      private

      def entry_json(referral)
        {
          id: referral.id,
          status: referral.status,
          referral_code_used: referral.referral_code_used,
          referrer_username: referral.referrer.username,
          referred_username: referral.referred.username,
          signed_up_at: referral.created_at.iso8601,
          qualified_at: referral.qualified_at&.iso8601,
          rewarded_at: referral.rewarded_at&.iso8601,
          referrer_bonus_cents: referral.referrer_bonus_cents,
          referrer_bonus_currency: referral.referrer_bonus_currency,
          qualifying_tip_reference: referral.qualifying_tip&.paystack_reference,
          metadata: referral.metadata
        }
      end
    end
  end
end

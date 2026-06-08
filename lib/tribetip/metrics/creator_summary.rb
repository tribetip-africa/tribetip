# frozen_string_literal: true

module Tribetip
  module Metrics
    class CreatorSummary
      Summary = Struct.new(
        :paid_tips_count,
        :pending_tips_count,
        :failed_tips_count,
        :total_earned_cents,
        :pending_tips_cents,
        :tips_last_30_days_count,
        :tips_last_30_days_cents,
        :last_paid_at,
        :currency,
        keyword_init: true
      ) do
        def as_json(*)
          {
            paid_tips_count: paid_tips_count,
            pending_tips_count: pending_tips_count,
            failed_tips_count: failed_tips_count,
            total_earned_cents: total_earned_cents,
            pending_tips_cents: pending_tips_cents,
            tips_last_30_days_count: tips_last_30_days_count,
            tips_last_30_days_cents: tips_last_30_days_cents,
            last_paid_at: last_paid_at,
            currency: currency
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
        tips = @tribe.tips
        paid = tips.paid
        pending = tips.where(status: "pending")
        failed = tips.where(status: "failed")
        recent = paid.where("paid_at >= ?", 30.days.ago)

        Summary.new(
          paid_tips_count: paid.count,
          pending_tips_count: pending.count,
          failed_tips_count: failed.count,
          total_earned_cents: paid.sum(:amount_cents),
          pending_tips_cents: pending.sum(:amount_cents),
          tips_last_30_days_count: recent.count,
          tips_last_30_days_cents: recent.sum(:amount_cents),
          last_paid_at: paid.maximum(:paid_at),
          currency: @tribe.currency
        )
      end
    end
  end
end

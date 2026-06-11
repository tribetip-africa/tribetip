# frozen_string_literal: true

module Tribetip
  module Paystack
    class RepairCreatorPayments
      Result = Struct.new(
        :settlements_synced_at,
        :settlements_count,
        :settlement_summary,
        :tips_examined,
        :tips_reconciled,
        :tips_still_pending,
        :payout,
        :earnings,
        :refreshed_at,
        keyword_init: true
      ) do
        def as_json(*)
          {
            settlements_synced_at: settlements_synced_at,
            settlements_count: settlements_count,
            settlement_summary: settlement_summary,
            tips_examined: tips_examined,
            tips_reconciled: tips_reconciled,
            tips_still_pending: tips_still_pending,
            payout: payout,
            earnings: earnings,
            refreshed_at: refreshed_at
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
        settlements_result = ListSettlements.call(@tribe, refresh: true)
        tips_examined = 0
        tips_reconciled = 0

        @tribe.tips.where(status: "pending").order(created_at: :asc).find_each do |tip|
          tips_examined += 1
          result = ReconcileTipPayment.call(tip, paid_via: :reconcile, actor_id: @tribe.id)
          tips_reconciled += 1 if result.success?
        end

        payout = FetchPayoutStatus.call(@tribe, refresh: true)
        earnings = Metrics::CreatorSummary.call(@tribe)
        settlement_summary = Metrics::SettlementSummary.call(@tribe)

        Result.new(
          settlements_synced_at: settlements_result.synced_at&.iso8601,
          settlements_count: settlements_result.settlements.length,
          settlement_summary: settlement_summary.as_json,
          tips_examined: tips_examined,
          tips_reconciled: tips_reconciled,
          tips_still_pending: @tribe.tips.where(status: "pending").count,
          payout: payout.as_json,
          earnings: earnings.as_json,
          refreshed_at: Time.current.iso8601
        )
      end
    end
  end
end

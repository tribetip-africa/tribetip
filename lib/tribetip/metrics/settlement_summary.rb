# frozen_string_literal: true

module Tribetip
  module Metrics
    class SettlementSummary
      Summary = Struct.new(
        :total_settled_cents,
        :successful_settlements_count,
        :failed_settlements_count,
        :last_settled_at,
        :currency,
        keyword_init: true
      ) do
        def as_json(*)
          {
            total_settled_cents: total_settled_cents,
            successful_settlements_count: successful_settlements_count,
            failed_settlements_count: failed_settlements_count,
            last_settled_at: last_settled_at,
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
        settlements = @tribe.paystack_settlements
        successful = settlements.where(status: "success")
        failed = settlements.where(status: %w[failed reversed])

        Summary.new(
          total_settled_cents: successful.sum(:amount_cents),
          successful_settlements_count: successful.count,
          failed_settlements_count: failed.count,
          last_settled_at: successful.maximum(:settled_at),
          currency: @tribe.currency
        )
      end
    end
  end
end

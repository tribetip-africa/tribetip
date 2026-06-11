# frozen_string_literal: true

module Tribetip
  module Paystack
    class AvailableBalance
      Result = Struct.new(:amount_cents, :currency, :source, keyword_init: true) do
        def as_json(*)
          {
            amount_cents: amount_cents,
            currency: currency,
            source: source
          }
        end
      end

      RESERVED_STATUSES = %w[pending processing success].freeze

      def self.call(tribe, refresh: false)
        new(tribe).call(refresh: refresh)
      end

      def initialize(tribe)
        @tribe = tribe
        @client = Client.new
        @market = Market.for_tribe(tribe)
      end

      def call(refresh: false)
        if @client.stub_mode?
          return Result.new(
            amount_cents: stub_available_cents,
            currency: @tribe.currency,
            source: "stub"
          )
        end

        payout = FetchPayoutStatus.call(@tribe, refresh: refresh)
        Result.new(
          amount_cents: payout.available_to_settle_cents.to_i,
          currency: payout.currency.presence || @tribe.currency,
          source: "paystack"
        )
      end

      private

      def stub_available_cents
        net_earned_cents = @tribe.tips.paid.sum do |tip|
          SettlementRecord.net_settlement_cents(tip.amount_cents)
        end
        reserved_cents = @tribe.paystack_settlements.where(status: RESERVED_STATUSES).sum(:amount_cents)

        [ net_earned_cents - reserved_cents, 0 ].max
      end
    end
  end
end

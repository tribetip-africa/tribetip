# frozen_string_literal: true

module Tribetip
  module Paystack
    class BuildSettlementDetail
      Detail = Struct.new(:settlement, :breakdown, :tip, keyword_init: true) do
        def as_json(*)
          {
            settlement: settlement,
            breakdown: breakdown,
            tip: tip
          }.compact
        end
      end

      def self.call(settlement)
        new(settlement).call
      end

      def initialize(settlement)
        @settlement = settlement
      end

      def call
        tip = linked_tip
        breakdown = build_breakdown(tip)

        Detail.new(
          settlement: settlement_json,
          breakdown: breakdown,
          tip: tip ? tip_summary(tip) : nil
        )
      end

      private

      def linked_tip
        @settlement.tip || find_tip_by_reference
      end

      def find_tip_by_reference
        reference = @settlement.reference.to_s
        return if reference.blank?

        @settlement.tribe.tips.find_by(paystack_reference: reference)
      end

      def build_breakdown(tip)
        net_cents = @settlement.amount_cents
        gross_cents = tip&.amount_cents
        fee_cents = gross_cents ? PlatformFee.fee_cents(gross_cents, net_cents: net_cents) : nil

        {
          gross_cents: gross_cents,
          platform_fee_cents: fee_cents,
          platform_fee_percent: PlatformFee.percent,
          net_cents: net_cents,
          currency: @settlement.currency
        }.compact
      end

      def settlement_json
        @settlement.to_settlement_record.as_json.merge(
          paystack_transfer_code: @settlement.paystack_transfer_code,
          tip_id: @settlement.tip_id
        )
      end

      def tip_summary(tip)
        {
          id: tip.id,
          paystack_reference: tip.paystack_reference,
          amount_cents: tip.amount_cents,
          currency: tip.currency,
          supporter_email: tip.supporter_email,
          supporter_name: tip.supporter_name,
          message: tip.message,
          paid_at: tip.paid_at&.iso8601
        }.compact
      end
    end
  end
end

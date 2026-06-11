# frozen_string_literal: true

module Tribetip
  module Notifications
    class RecordSettlement
      KINDS = {
        "success" => "settlement_paid",
        "failed" => "settlement_failed",
        "reversed" => "settlement_failed"
      }.freeze

      def self.call(settlement, event_type:)
        new(settlement, event_type: event_type).call
      end

      def initialize(settlement, event_type:)
        @settlement = settlement
        @event_type = event_type
      end

      def call
        kind = KINDS[@settlement.status]
        return if kind.blank?

        tribe = @settlement.tribe
        return if tribe.creator_notifications.where(kind: kind).where(
          "metadata->>'paystack_transfer_code' = ?",
          @settlement.paystack_transfer_code
        ).exists?

        tribe.creator_notifications.create!(
          kind: kind,
          title: notification_title,
          body: notification_body,
          metadata: {
            paystack_transfer_code: @settlement.paystack_transfer_code,
            settlement_id: @settlement.id,
            amount_cents: @settlement.amount_cents,
            currency: @settlement.currency,
            status: @settlement.status,
            event_type: @event_type,
            destination: @settlement.destination
          }
        )
      end

      private

      def notification_title
        case @settlement.status
        when "success"
          "Settlement sent"
        else
          "Settlement issue"
        end
      end

      def notification_body
        amount = format_amount
        destination = @settlement.destination.presence || "your linked payout account"

        case @settlement.status
        when "success"
          "#{amount} was sent to #{destination}."
        else
          "Paystack reported #{@event_type.to_s.tr('.', ' ')} for #{amount}."
        end
      end

      def format_amount
        units = @settlement.amount_cents / 100.0
        format("%.2f %s", units, @settlement.currency)
      end
    end
  end
end

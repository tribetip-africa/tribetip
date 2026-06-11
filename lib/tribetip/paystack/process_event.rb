# frozen_string_literal: true

module Tribetip
  module Paystack
    class ProcessEvent
      def self.call(event, paystack_event: nil)
        new(event, paystack_event: paystack_event).call
      end

      def initialize(event, paystack_event: nil)
        @event = event
        @paystack_event = paystack_event
      end

      def call
        case @event["event"]
        when "charge.success", "charge.failed"
          reconcile_tip
        when "transfer.success", "transfer.failed", "transfer.reversed"
          record_settlement
        end
      end

      private

      def reconcile_tip
        tip = find_tip
        return unless tip

        link_paystack_event!(tip)
        Tribetip::Paystack::ReconcileTipPayment.call(
          tip,
          paid_via: :webhook,
          paystack_event: @paystack_event
        )
      end

      def record_settlement
        Tribetip::Paystack::RecordSettlement.call(
          payload: @event["data"],
          event_type: @event["event"],
          paystack_event: @paystack_event
        )
      end

      def link_paystack_event!(tip)
        return unless @paystack_event
        return if @paystack_event.tip_id == tip.id

        @paystack_event.update!(tip_id: tip.id)
      end

      def find_tip
        reference = @event.dig("data", "reference")
        return if reference.blank?

        Tip.find_by(paystack_reference: reference)
      end
    end
  end
end

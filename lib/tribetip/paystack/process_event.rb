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

        verify_tip_metadata!(tip)
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

      def verify_tip_metadata!(tip)
        data = @event["data"]
        return unless data.is_a?(Hash)

        metadata = data["metadata"]
        return unless metadata.is_a?(Hash)

        metadata = metadata.with_indifferent_access
        if metadata[:tip_id].present? && metadata[:tip_id].to_s != tip.id.to_s
          raise Tribetip::Errors::BadRequest.new(
            "Paystack tip metadata does not match the referenced tip.",
            details: { expected_tip_id: tip.id, metadata_tip_id: metadata[:tip_id] }
          )
        end

        if metadata[:tribe_id].present? && metadata[:tribe_id].to_s != tip.tribe_id.to_s
          raise Tribetip::Errors::BadRequest.new(
            "Paystack tribe metadata does not match the referenced tip.",
            details: { expected_tribe_id: tip.tribe_id, metadata_tribe_id: metadata[:tribe_id] }
          )
        end
      end
    end
  end
end

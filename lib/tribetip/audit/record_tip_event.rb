# frozen_string_literal: true

module Tribetip
  module Audit
    class RecordTipEvent
      RequestContext = Struct.new(:request_id, :ip, keyword_init: true)

      def self.call(**kwargs)
        new(**kwargs).call
      end

      def initialize(
        tip:,
        action:,
        source:,
        from_status: nil,
        to_status: nil,
        actor_id: nil,
        paystack_event: nil,
        paid_via: nil,
        failed_reason: nil,
        verification: nil,
        metadata: nil,
        request_context: nil
      )
        @tip = tip
        @action = action
        @source = source
        @from_status = from_status
        @to_status = to_status
        @actor_id = actor_id
        @paystack_event = paystack_event
        @paid_via = paid_via
        @failed_reason = failed_reason
        @verification = verification
        @metadata = metadata
        @request_context = request_context
      end

      def call
        event = TipEvent.create!(
          tip: @tip,
          paystack_event: @paystack_event,
          action: @action,
          from_status: @from_status,
          to_status: @to_status,
          source: @source,
          actor_id: @actor_id,
          paystack_reference: @tip.paystack_reference,
          paid_via: @paid_via,
          failed_reason: @failed_reason,
          verification: @verification || {},
          metadata: @metadata || {},
          request_id: @request_context&.request_id,
          ip: @request_context&.ip
        )

        PaymentLogger.log(
          event: "tip_#{@action}",
          tip_id: @tip.id,
          paystack_reference: @tip.paystack_reference,
          paystack_event_id: @paystack_event&.id,
          source: @source,
          from_status: @from_status,
          to_status: @to_status,
          paid_via: @paid_via,
          failed_reason: @failed_reason
        )

        event
      end
    end
  end
end

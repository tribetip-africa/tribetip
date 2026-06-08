# frozen_string_literal: true

module Tribetip
  module Audit
    class InvestigateTip
      def self.call(paystack_reference)
        new(paystack_reference).call
      end

      def initialize(paystack_reference)
        @paystack_reference = paystack_reference
      end

      def call
        tip = Tip.find_by!(paystack_reference: @paystack_reference)
        tribe = tip.tribe

        {
          tip: tip_payload(tip),
          tip_events: TipEvent.where(tip_id: tip.id).recent_first.map(&:as_json),
          paystack_events: PaystackEvent.where(tip_id: tip.id)
            .or(PaystackEvent.where("payload -> 'data' ->> 'reference' = ?", @paystack_reference))
            .recent_first
            .map { |event| paystack_event_payload(event) },
          tribe_versions: tribe_versions_for(tribe),
          admin_audit_logs: admin_logs_for(tip, tribe)
        }
      end

      private

      def tip_payload(tip)
        {
          id: tip.id,
          tribe_id: tip.tribe_id,
          tribe_username: tip.tribe.username,
          amount_cents: tip.amount_cents,
          currency: tip.currency,
          status: tip.status,
          paystack_reference: tip.paystack_reference,
          paid_at: tip.paid_at,
          paid_via: tip.paid_via,
          failed_reason: tip.failed_reason,
          last_paystack_event_id: tip.last_paystack_event_id,
          paystack_metadata: tip.paystack_metadata,
          created_at: tip.created_at,
          updated_at: tip.updated_at
        }
      end

      def paystack_event_payload(event)
        {
          id: event.id,
          event_id: event.event_id,
          event_type: event.event_type,
          status: event.status,
          tip_id: event.tip_id,
          error_message: event.error_message,
          processed_at: event.processed_at,
          created_at: event.created_at,
          paystack_reference: event.payload.dig("data", "reference")
        }
      end

      def tribe_versions_for(tribe)
        Version
          .where(item_type: "Tribe", item_id: tribe.id)
          .order(created_at: :desc)
          .limit(20)
          .map do |version|
            {
              id: version.id,
              event: version.event,
              whodunnit: version.whodunnit,
              object_changes: version.object_changes,
              request_id: version.request_id,
              ip: version.ip,
              created_at: version.created_at
            }
          end
      end

      def admin_logs_for(tip, tribe)
        AdminAuditLog
          .where(target_type: "Tip", target_id: tip.id.to_s)
          .or(
            AdminAuditLog.where(target_type: "Tribe", target_id: tribe.id.to_s)
          )
          .or(
            AdminAuditLog.where(target_type: "PaystackEvent")
              .where("details ->> 'paystack_reference' = ?", @paystack_reference)
          )
          .recent_first
          .limit(20)
          .map(&:as_json)
      end
    end
  end
end

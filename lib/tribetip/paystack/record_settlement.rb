# frozen_string_literal: true

module Tribetip
  module Paystack
    class RecordSettlement
      Result = Struct.new(:settlement, :skipped, keyword_init: true)

      def self.call(payload: nil, event_type: nil, paystack_event: nil, tribe: nil, record: nil)
        new(
          payload: payload,
          event_type: event_type,
          paystack_event: paystack_event,
          tribe: tribe,
          record: record
        ).call
      end

      def initialize(payload: nil, event_type: nil, paystack_event: nil, tribe: nil, record: nil)
        @payload = payload&.with_indifferent_access
        @event_type = event_type
        @paystack_event = paystack_event
        @tribe = tribe
        @record = record
      end

      def call
        tribe = @tribe || find_tribe_from_payload
        return Result.new(skipped: true) unless tribe

        attributes = build_attributes(tribe)
        return Result.new(skipped: true) if attributes[:paystack_transfer_code].blank?

        settlement = PaystackSettlement.find_or_initialize_by(
          paystack_transfer_code: attributes[:paystack_transfer_code]
        )
        previous_status = settlement.status if settlement.persisted?
        settlement.assign_attributes(attributes)
        settlement.save!

        ListSettlements.invalidate_cache(tribe)
        notify_creator_if_needed!(settlement, previous_status)
        Tribetip::Audit::PaymentLogger.log(
          event: "settlement_recorded",
          tribe_id: tribe.id,
          paystack_event_id: @paystack_event&.id,
          metadata: {
            paystack_transfer_code: settlement.paystack_transfer_code,
            status: settlement.status,
            amount_cents: settlement.amount_cents
          }
        )

        Result.new(settlement: settlement)
      end

      private

      def build_attributes(tribe)
        if @record
          return record_attributes(tribe, @record)
        end

        payload_attributes(tribe)
      end

      def record_attributes(tribe, record)
        {
          tribe: tribe,
          paystack_event: @paystack_event,
          tip_id: linked_tip_id(tribe),
          paystack_transfer_code: record.id,
          amount_cents: record.amount_cents,
          currency: record.currency,
          status: record.status,
          settled_at: record.settled_at,
          destination: record.destination,
          reference: record.reference,
          metadata: {
            source: "sync",
            synced_at: Time.current.iso8601
          }
        }
      end

      def payload_attributes(tribe)
        record = SettlementRecord.from_transfer(@payload, tribe: tribe)
        status = status_from_event_type || record.status

        {
          tribe: tribe,
          paystack_event: @paystack_event,
          tip_id: linked_tip_id(tribe, record.reference),
          paystack_transfer_code: transfer_code,
          amount_cents: record.amount_cents,
          currency: record.currency,
          status: status,
          settled_at: record.settled_at || Time.current,
          destination: record.destination,
          reference: record.reference,
          metadata: {
            source: "webhook",
            event_type: @event_type,
            payload: @payload.except("recipient")
          }
        }
      end

      def transfer_code
        @payload[:transfer_code].presence || @payload[:id].presence || @record&.id
      end

      def status_from_event_type
        case @event_type.to_s
        when "transfer.success"
          "success"
        when "transfer.failed"
          "failed"
        when "transfer.reversed"
          "reversed"
        end
      end

      def find_tribe_from_payload
        return if @payload.blank?

        metadata = @payload[:metadata].is_a?(Hash) ? @payload[:metadata].with_indifferent_access : {}
        tribe = Tribe.find_by(id: metadata[:tribe_id]) if metadata[:tribe_id].present?
        return tribe if tribe

        subaccount_code = metadata[:subaccount_code].to_s.presence
        subaccount_code ||= subaccount_code_from_reason(@payload[:reason])
        return if subaccount_code.blank?

        Tribe.find_by(paystack_subaccount_code: subaccount_code)
      end

      def subaccount_code_from_reason(reason)
        code = reason.to_s[/ACCT_[a-zA-Z0-9_]+/]
        code.presence
      end

      def notify_creator_if_needed!(settlement, previous_status)
        return if @event_type.blank?
        return unless settlement.status.in?(%w[success failed reversed])
        return if previous_status == settlement.status

        ::Paystack::NotifySettlementJob.perform_later(settlement.id, @event_type)
      end

      def linked_tip_id(tribe, reference = nil)
        metadata = @payload&.dig(:metadata)
        metadata = metadata.with_indifferent_access if metadata.is_a?(Hash)
        metadata_tip_id = metadata&.dig(:tip_id).presence
        if metadata_tip_id
          tip = tribe.tips.find_by(id: metadata_tip_id)
          return tip.id if tip
        end

        ref = reference.presence || @payload&.dig(:reference).presence || @record&.reference
        return if ref.blank?

        tribe.tips.find_by(paystack_reference: ref)&.id
      end
    end
  end
end

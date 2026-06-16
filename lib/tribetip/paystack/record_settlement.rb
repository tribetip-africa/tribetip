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

        settlement = find_or_build_settlement(tribe, attributes)
        previous_status = settlement.status if settlement.persisted?
        previous_transfer_code = settlement.paystack_transfer_code
        settlement.assign_attributes(attributes)
        restore_authoritative_transfer_code!(settlement, previous_transfer_code, attributes[:paystack_transfer_code])
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
            amount_cents: settlement.amount_cents,
            tip_id: settlement.tip_id
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
        tip_id = linked_tip_id(tribe, record.reference)

        {
          tribe: tribe,
          paystack_event: @paystack_event,
          tip_id: tip_id,
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
        tip_id = linked_tip_id(tribe, record.reference)

        {
          tribe: tribe,
          paystack_event: @paystack_event,
          tip_id: tip_id,
          paystack_transfer_code: transfer_code,
          amount_cents: record.amount_cents,
          currency: record.currency,
          status: status,
          settled_at: record.settled_at || Time.current,
          destination: record.destination,
          reference: record.reference,
          metadata: {
            source: metadata_source,
            event_type: @event_type,
            payload: @payload.except("recipient")
          }.compact
        }
      end

      def metadata_source
        source = @payload&.dig(:metadata, :source).presence
        return source if source.present?

        @event_type.present? ? "webhook" : "sync"
      end

      def find_or_build_settlement(tribe, attributes)
        incoming_code = attributes[:paystack_transfer_code]
        settlement = PaystackSettlement.find_by(paystack_transfer_code: incoming_code)
        return settlement if settlement

        tip_id = attributes[:tip_id]
        tip_id ||= tip_id_for_reference(tribe, attributes[:reference])
        attributes[:tip_id] = tip_id if tip_id.present?

        if tip_id.present?
          existing = tribe.paystack_settlements.find_by(tip_id: tip_id)
          return reconcile_duplicate!(existing, attributes) if existing
        end

        stub_code = SettlementRecord.transfer_code_for_reference(attributes[:reference])
        if stub_code.present?
          existing = PaystackSettlement.find_by(paystack_transfer_code: stub_code)
          return reconcile_duplicate!(existing, attributes) if existing
        end

        PaystackSettlement.new(paystack_transfer_code: incoming_code)
      end

      def reconcile_duplicate!(existing, attributes)
        incoming_code = attributes[:paystack_transfer_code]
        preferred_code = preferred_transfer_code(existing.paystack_transfer_code, incoming_code)

        if preferred_code != existing.paystack_transfer_code &&
           !PaystackSettlement.exists?(paystack_transfer_code: preferred_code)
          existing.paystack_transfer_code = preferred_code
        end

        existing
      end

      def preferred_transfer_code(existing_code, incoming_code)
        existing_rank = SettlementRecord.transfer_code_rank(existing_code)
        incoming_rank = SettlementRecord.transfer_code_rank(incoming_code)

        incoming_rank > existing_rank ? incoming_code : existing_code
      end

      def restore_authoritative_transfer_code!(settlement, previous_code, incoming_code)
        return if previous_code.blank? || incoming_code.blank?
        return if previous_code == incoming_code

        preferred = preferred_transfer_code(previous_code, incoming_code)
        settlement.paystack_transfer_code = preferred
      end

      def tip_id_for_reference(tribe, reference)
        return if reference.blank?

        tribe.tips.find_by(paystack_reference: reference)&.id
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

        ResolveSettlementTribe.call(@payload).tribe
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

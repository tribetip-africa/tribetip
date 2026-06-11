# frozen_string_literal: true

require "digest"

module Tribetip
  module Paystack
    class RegisterWebhookEvent
      Result = Struct.new(:event, :duplicate, keyword_init: true)

      def self.call(payload)
        new(payload).call
      end

      def initialize(payload)
        @payload = payload
      end

      def call
        event = PaystackEvent.find_by(event_id: event_id)
        return Result.new(event: event, duplicate: true) if event

        event = PaystackEvent.create!(
          event_id: event_id,
          event_type: @payload.fetch("event"),
          payload: @payload,
          status: "pending",
          tip_id: tip_id_for_payload
        )

        Tribetip::Audit::PaymentLogger.log(
          event: "webhook_received",
          paystack_event_id: event.id,
          event_type: event.event_type,
          paystack_reference: @payload.dig("data", "reference"),
          tip_id: event.tip_id
        )

        Result.new(event: event, duplicate: false)
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        existing = PaystackEvent.find_by!(event_id: event_id)
        Result.new(event: existing, duplicate: true)
      end

      private

      def event_id
        event_name = @payload["event"].to_s
        if event_name.start_with?("transfer.")
          transfer_code = @payload.dig("data", "transfer_code") || @payload.dig("data", "id")
          return "paystack:#{event_name}:#{transfer_code}" if transfer_code.present?
        end

        reference = @payload.dig("data", "reference")
        paystack_id = @payload.dig("data", "id")
        return "paystack:#{@payload['event']}:#{paystack_id}" if paystack_id.present?
        return "paystack:#{@payload['event']}:#{reference}" if reference.present?

        Digest::SHA256.hexdigest(@payload.to_json)
      end

      def tip_id_for_payload
        reference = @payload.dig("data", "reference")
        return if reference.blank?

        Tip.find_by(paystack_reference: reference)&.id
      end
    end
  end
end

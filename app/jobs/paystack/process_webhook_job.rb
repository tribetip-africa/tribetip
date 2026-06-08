# frozen_string_literal: true

module Paystack
  class ProcessWebhookJob < ApplicationJob
    queue_as :webhooks

    limits_concurrency to: 1, key: ->(paystack_event_id) { "paystack-event/#{paystack_event_id}" }, duration: 1.hour
    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    def perform(paystack_event_id)
      event = PaystackEvent.find_by(id: paystack_event_id)
      return unless event
      return if event.processed?

      run_job_step(paystack_event_id: paystack_event_id) do
        event.mark_processing!
        Tribetip::Paystack::ProcessEvent.call(event.payload, paystack_event: event)
        event.mark_processed!

        Tribetip::Audit::PaymentLogger.log(
          event: "webhook_processed",
          paystack_event_id: event.id,
          tip_id: event.tip_id,
          paystack_reference: event.payload.dig("data", "reference")
        )
      end
    rescue StandardError => e
      event&.mark_failed!(e.message)
      raise
    end
  end
end

# frozen_string_literal: true

module Paystack
  class InitializeTipCheckoutJob < ApplicationJob
    queue_as :paystack

    limits_concurrency to: 1, key: ->(tip_id) { "tip-checkout/#{tip_id}" }, duration: 10.minutes

    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    def perform(tip_id)
      tip = Tip.find_by(id: tip_id)
      return unless tip
      return if tip.paystack_metadata["authorization_url"].present?

      run_job_step(tip_id: tip_id) do
        tribe = tip.tribe
        market = Tribetip::Paystack::Market.for_tribe(tribe)
        checkout = Tribetip::Paystack::Client.new.initialize_transaction(
          email: tip.supporter_email,
          amount_cents: tip.amount_cents,
          currency: tip.currency,
          reference: tip.paystack_reference,
          callback_url: Tribetip::Platform.app_url + "/#{tribe.username}?tip=success",
          metadata: market.paystack_metadata_for(tribe).merge(tip_id: tip.id),
          subaccount: tribe.paystack_subaccount_code
        )

        unless checkout.success?
          tip.update!(
            paystack_metadata: tip.paystack_metadata.merge(
              "checkout_status" => "failed",
              "checkout_error" => checkout.message
            )
          )
          record_checkout_event(tip, action: "checkout_failed", message: checkout.message)
          raise StandardError, checkout.message || "Unable to initialize Paystack checkout."
        end

        tip.update!(
          paystack_metadata: {
            "authorization_url" => checkout.authorization_url,
            "access_code" => checkout.access_code,
            "checkout_status" => "ready"
          }
        )
        record_checkout_event(tip, action: "checkout_ready")
      end
    end

    private

    def record_checkout_event(tip, action:, message: nil)
      Tribetip::Audit::RecordTipEvent.call(
        tip: tip,
        action: action,
        from_status: tip.status,
        to_status: tip.status,
        source: "checkout_job",
        actor_id: "job:#{self.class.name}",
        failed_reason: message,
        metadata: tip.paystack_metadata
      )
    end
  end
end

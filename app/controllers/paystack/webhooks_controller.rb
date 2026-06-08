# frozen_string_literal: true

module Paystack
  class WebhooksController < ApplicationController
    def create
      payload = request.raw_post
      signature = request.headers["x-paystack-signature"]

      unless paystack_client.verify_webhook_signature(payload, signature)
        return render_error(Tribetip::Errors::BadRequest.new("Invalid Paystack signature."))
      end

      event_payload = JSON.parse(payload)
      registration = Tribetip::Paystack::RegisterWebhookEvent.call(event_payload)

      if registration.duplicate && registration.event.processed?
        return head :ok
      end

      ::Paystack::ProcessWebhookJob.perform_later(registration.event.id)

      head :ok
    rescue JSON::ParserError
      render_error(Tribetip::Errors::BadRequest.new("Invalid webhook payload."))
    end

    private

    def paystack_client
      @paystack_client ||= Tribetip::Paystack::Client.new
    end
  end
end

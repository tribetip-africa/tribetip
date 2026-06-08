# frozen_string_literal: true

module Paystack
  class RetryFailedWebhookEventsJob < ApplicationJob
    queue_as :webhooks

    BATCH_SIZE = 50

    def perform
      PaystackEvent.retryable.order(created_at: :asc).limit(BATCH_SIZE).find_each(&:replay!)
    end
  end
end

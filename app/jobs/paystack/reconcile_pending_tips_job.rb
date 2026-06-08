# frozen_string_literal: true

module Paystack
  class ReconcilePendingTipsJob < ApplicationJob
    queue_as :default

    PENDING_AGE = 15.minutes
    BATCH_SIZE = 100

    def perform
      Tip.pending_older_than(PENDING_AGE).order(created_at: :asc).limit(BATCH_SIZE).find_each do |tip|
        reconcile_tip(tip)
      end
    end

    private

    def reconcile_tip(tip)
      Tribetip::Paystack::ReconcileTipPayment.call(tip, paid_via: :sweep)
    rescue Tribetip::Errors::Base => error
      Rails.logger.warn(
        "[ReconcilePendingTipsJob] tip=#{tip.id} reference=#{tip.paystack_reference} error=#{error.message}"
      )
    end
  end
end

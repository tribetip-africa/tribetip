# frozen_string_literal: true

module Paystack
  class SyncSettlementsJob < ApplicationJob
    queue_as :default

    BATCH_SIZE = 50

    def perform
      Tribe.where(role: "creator")
           .where.not(paystack_subaccount_code: [ nil, "" ])
           .order(updated_at: :asc)
           .limit(BATCH_SIZE)
           .find_each do |tribe|
        Tribetip::Paystack::ListSettlements.call(tribe, refresh: true)
      rescue StandardError => error
        Rails.logger.warn(
          "[SyncSettlementsJob] tribe=#{tribe.id} username=#{tribe.username} error=#{error.message}"
        )
      end
    end
  end
end

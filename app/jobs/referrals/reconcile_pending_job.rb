# frozen_string_literal: true

module Referrals
  class ReconcilePendingJob < ApplicationJob
    queue_as :default

    BATCH_SIZE = 100

    def perform
      return unless Tribetip::Referrals::Config.enabled?

      Referral.pending.includes(:referred).limit(BATCH_SIZE).find_each do |referral|
        tip = referral.referred.tips.paid.order(:paid_at, :created_at).first
        next unless tip

        Referrals::ProcessPaidTipJob.perform_later(tip_id: tip.id)
      end

      Referral.where(status: "qualified").where(rewarded_at: nil).limit(BATCH_SIZE).find_each do |referral|
        Referrals::IssueReferrerBonusJob.perform_later(referral.id)
      end
    end
  end
end

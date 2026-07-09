# frozen_string_literal: true

module Referrals
  class IssueReferrerBonusJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    def perform(referral_id)
      referral = Referral.find_by(id: referral_id)
      return unless referral

      Tribetip::Referrals::IssueReferrerBonus.call(referral)
    end
  end
end

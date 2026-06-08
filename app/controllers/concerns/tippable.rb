# frozen_string_literal: true

module Tippable
  extend ActiveSupport::Concern

  private

  def find_tippable_tribe!(username)
    tribe = Tribe.find_by(username: username.to_s.downcase)
    raise ActiveRecord::RecordNotFound if tribe.nil?
    raise ActiveRecord::RecordNotFound unless tippable?(tribe)

    tribe
  end

  def tippable?(tribe)
    tribe.creator? &&
      tribe.is_profile_public? &&
      tribe.account_status == "active" &&
      !tribe.suspended? &&
      tribe.paystack_subaccount_ready? &&
      tribe.paystack_onboarding_complete?
  end
end

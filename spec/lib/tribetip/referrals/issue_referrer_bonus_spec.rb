# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Referrals::IssueReferrerBonus do
  it "marks a qualified referral as rewarded and records a notification" do
    referrer = create_creator(username: "bonus_referrer")
    referred = create_onboarded_tribe(username: "bonus_referred")
    referral = Referral.create!(
      referrer: referrer,
      referred: referred,
      referral_code_used: referrer.username,
      status: "qualified",
      qualified_at: Time.current
    )

    result = described_class.call(referral)

    expect(result.success?).to be(true)
    referral.reload
    expect(referral.status).to eq("rewarded")
    expect(referral.rewarded_at).to be_present
    expect(referral.referrer_bonus_cents).to eq(Tribetip::Referrals::Config.referrer_bonus_cents(referrer.currency))
    expect(referrer.creator_notifications.where(kind: "referral_bonus_paid").count).to eq(1)
  end
end

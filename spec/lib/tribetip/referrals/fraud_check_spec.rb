# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Referrals::FraudCheck do
  it "blocks referrals when signup IP matches the referrer sign-in IP" do
    referrer = create_creator(username: "fraud_referrer")
    referrer.update!(current_sign_in_ip: "203.0.113.10")

    expect(
      described_class.attach_block_reason(referrer: referrer, signup_ip: "203.0.113.10")
    ).to eq("same_ip_signup")
  end

  it "blocks referrals when the referrer is at capacity" do
    referrer = create_creator(username: "capacity_referrer")
    referred = create_tribe(username: "capacity_referred")
    Referral.create!(
      referrer: referrer,
      referred: referred,
      referral_code_used: referrer.username,
      status: "pending"
    )

    allow(Tribetip::Referrals::Config).to receive(:max_referrals_per_referrer).and_return(1)

    expect(described_class.referrer_at_capacity?(referrer)).to be(true)
  end

  it "flags suspended referrers during qualification" do
    referrer = create_creator(username: "suspended_bonus_referrer", account_status: "suspended")
    referred = create_onboarded_tribe(username: "suspended_bonus_referred")
    referral = Referral.create!(
      referrer: referrer,
      referred: referred,
      referral_code_used: referrer.username,
      status: "pending"
    )

    expect(described_class.qualification_block_reason(referral)).to eq("referrer_suspended")
  end
end

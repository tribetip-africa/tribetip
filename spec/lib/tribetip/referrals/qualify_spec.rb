# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Referrals::Qualify do
  def create_paid_tip(tribe, amount_cents: 50_000)
    tip = tribe.tips.create!(
      amount_cents: amount_cents,
      currency: tribe.currency,
      status: "pending",
      paystack_reference: Tip.generate_reference,
      supporter_email: "fan@example.com"
    )
    tip.update_columns(status: "paid", paid_at: Time.current, paid_via: "reconcile")
    tip
  end

  it "qualifies a pending referral on the referred creator's first paid tip" do
    referrer = create_creator(username: "qualify_referrer")
    referred = create_onboarded_tribe(username: "qualify_referred")
    Referral.create!(
      referrer: referrer,
      referred: referred,
      referral_code_used: referrer.username,
      status: "pending"
    )

    tip = create_paid_tip(referred)

    allow(::Referrals::IssueReferrerBonusJob).to receive(:perform_later)

    result = described_class.call(tip)

    expect(result.qualified?).to be(true)
    referral = result.referral
    expect(referral.status).to eq("qualified")
    expect(referral.qualifying_tip).to eq(tip)
    expect(referred.reload.referral_fee_credit_cents_remaining).to be_positive
    expect(referrer.creator_notifications.where(kind: "referral_qualified").count).to eq(1)
    expect(referred.creator_notifications.where(kind: "referral_welcome_bonus").count).to eq(1)
  end

  it "does not qualify when onboarding is incomplete" do
    referrer = create_creator(username: "pending_qualify_referrer")
    referred = create_tribe(username: "pending_qualify_referred")
    Referral.create!(
      referrer: referrer,
      referred: referred,
      referral_code_used: referrer.username,
      status: "pending"
    )

    tip = create_paid_tip(referred)

    expect(described_class.call(tip).qualified?).to be(false)
    expect(Referral.find_by!(referred: referred).status).to eq("pending")
  end

  it "does not qualify on the second paid tip" do
    referrer = create_creator(username: "second_tip_referrer")
    referred = create_onboarded_tribe(username: "second_tip_referred")
    Referral.create!(
      referrer: referrer,
      referred: referred,
      referral_code_used: referrer.username,
      status: "pending"
    )

    create_paid_tip(referred)
    second_tip = create_paid_tip(referred)

    expect(described_class.call(second_tip).qualified?).to be(false)
  end

  it "auto-rejects referrals with the same signup IP as the referrer" do
    referrer = create_creator(username: "qualify_same_ip_referrer")
    referrer.update!(current_sign_in_ip: "203.0.113.44")
    referred = create_onboarded_tribe(username: "qualify_same_ip_referred")
    referral = Referral.create!(
      referrer: referrer,
      referred: referred,
      referral_code_used: referrer.username,
      status: "pending",
      metadata: { "signup_ip" => "203.0.113.44" }
    )

    allow(::Referrals::IssueReferrerBonusJob).to receive(:perform_later)
    tip = create_paid_tip(referred)

    result = described_class.call(tip)

    expect(result.qualified?).to be(false)
    expect(referral.reload.status).to eq("rejected")
    expect(referral.metadata["rejected_reason"]).to eq("same_ip_signup")
  end
end

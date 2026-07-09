# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Referrals::ConsumeFeeCredit do
  it "applies referral fee credit to a paid tip" do
    tribe = create_onboarded_tribe(username: "credit_creator", referral_fee_credit_cents_remaining: 10_000)
    tip = tribe.tips.create!(
      amount_cents: 50_000,
      currency: tribe.currency,
      status: "pending",
      paystack_reference: Tip.generate_reference,
      supporter_email: "fan@example.com"
    )
    tip.update_columns(status: "paid", paid_at: Time.current, paid_via: "reconcile")

    result = described_class.call(tip)

    expect(result.applied_cents).to be_positive
    expect(tribe.reload.referral_fee_credit_cents_remaining).to eq(10_000 - result.applied_cents)
    expect(tip.reload.paystack_metadata["referral_fee_credit_applied_cents"]).to eq(result.applied_cents)
  end
end

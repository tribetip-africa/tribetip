# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::InitiateWithdrawal do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("TRIBETIP_PAYOUT_MODE", "auto").and_return("manual")
    allow(ENV).to receive(:[]).with("TRIBETIP_PAYSTACK_TRANSFERS_ENABLED").and_return("true")
    Tribetip::Paystack::FetchPayoutCapabilities.clear!
  end

  it "withdraws the full available balance for a creator" do
    tribe = create_onboarded_tribe(username: "withdraw_creator")
    tribe.tips.create!(
      amount_cents: 100_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_withdraw",
      supporter_email: "fan@example.com",
      paid_at: 1.day.ago
    )

    result = described_class.call(tribe)

    expect(result.success?).to be(true)
    expect(result.settlement.amount_cents).to eq(95_000)
    expect(result.settlement.status).to eq("success")
    expect(result.settlement.metadata["source"]).to eq("manual_withdrawal")
    expect(Tribetip::Paystack::BuildWithdrawalStatus.call(tribe).available_to_withdraw_cents).to eq(0)
  end

  it "rejects withdrawal when no balance is available" do
    tribe = create_onboarded_tribe(username: "withdraw_empty")

    result = described_class.call(tribe)

    expect(result.success?).to be(false)
    expect(result.message).to include("No funds")
  end
end

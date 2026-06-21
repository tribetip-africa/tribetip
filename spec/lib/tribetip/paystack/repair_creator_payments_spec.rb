# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::RepairCreatorPayments do
  it "syncs settlements and reconciles pending tips" do
    tribe = create_onboarded_tribe(username: "repair_payments")
    tribe.tips.create!(
      amount_cents: 50_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_repair_paid",
      supporter_email: "fan@example.com",
      paid_at: 1.day.ago
    )
    tribe.tips.create!(
      amount_cents: 25_000,
      currency: "KES",
      status: "pending",
      paystack_reference: "tip_repair_pending",
      supporter_email: "fan2@example.com"
    )

    result = described_class.call(tribe)

    expect(result.settlements_count).to eq(1)
    expect(result.tips_examined).to eq(1)
    expect(result.tips_reconciled).to eq(1)
    expect(result.tips_still_pending).to eq(0)
    expect(result.payout).to be_present
    expect(result.earnings).to be_present
  end
end

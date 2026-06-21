# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::ListSettlements do
  it "returns stub settlements from paid tips" do
    tribe = create_onboarded_tribe(username: "settlements_creator")
    tribe.tips.create!(
      amount_cents: 50_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_settlement_stub",
      supporter_email: "fan@example.com",
      paid_at: 2.days.ago
    )

    settlements = described_class.call(tribe, refresh: true)

    expect(settlements.settlements.length).to eq(1)
    expect(settlements.settlements.first.amount_cents).to eq(47_500)
  end

  it "does not create duplicate stub settlements when refreshed repeatedly" do
    tribe = create_onboarded_tribe(username: "settlements_refresh")
    tribe.tips.create!(
      amount_cents: 50_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_settlement_refresh",
      supporter_email: "fan@example.com",
      paid_at: 2.days.ago
    )

    described_class.call(tribe, refresh: true)
    described_class.call(tribe, refresh: true)

    expect(PaystackSettlement.where(tribe: tribe).count).to eq(1)
  end

  it "returns an empty list when no payouts are linked" do
    tribe = Tribe.create!(
      email: "unsettled@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "unsettled_creator",
      country_code: "KE",
      currency: "KES"
    )

    expect(described_class.call(tribe, refresh: true).settlements).to eq([])
  end
end

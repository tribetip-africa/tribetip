# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::BuildSettlementDetail do
  def create_tribe(username:)
    tribe = Tribe.create!(
      email: "#{username}@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: username,
      country_code: "KE",
      currency: "KES"
    )
    complete_stub_paystack_onboarding!(tribe)
    tribe.reload
  end

  it "returns settlement breakdown linked to the originating tip" do
    tribe = create_tribe(username: "settlement_detail")
    tip = tribe.tips.create!(
      amount_cents: 100_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_settlement_detail",
      supporter_email: "fan@example.com",
      paid_at: 1.day.ago
    )
    settlement = tribe.paystack_settlements.create!(
      paystack_transfer_code: "settlement_tip_settlement_detail",
      amount_cents: 95_000,
      currency: "KES",
      status: "success",
      settled_at: Time.current,
      destination: "M-PESA · ••5678",
      reference: tip.paystack_reference,
      tip: tip
    )

    detail = described_class.call(settlement)

    expect(detail.breakdown).to include(
      gross_cents: 100_000,
      platform_fee_cents: 5_000,
      platform_fee_percent: 5.0,
      net_cents: 95_000,
      currency: "KES"
    )
    expect(detail.tip).to include(
      id: tip.id,
      paystack_reference: "tip_settlement_detail",
      amount_cents: 100_000
    )
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Metrics::SettlementSummary do
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

  it "summarizes successful and failed settlement rows" do
    tribe = create_tribe(username: "settlement_summary")

    tribe.paystack_settlements.create!(
      paystack_transfer_code: "TRF_success_1",
      amount_cents: 95_000,
      currency: "KES",
      status: "success",
      settled_at: 2.days.ago
    )
    tribe.paystack_settlements.create!(
      paystack_transfer_code: "TRF_success_2",
      amount_cents: 47_500,
      currency: "KES",
      status: "success",
      settled_at: 1.day.ago
    )
    tribe.paystack_settlements.create!(
      paystack_transfer_code: "TRF_failed_1",
      amount_cents: 10_000,
      currency: "KES",
      status: "failed",
      settled_at: 3.days.ago
    )

    summary = described_class.call(tribe)

    expect(summary).to have_attributes(
      total_settled_cents: 142_500,
      successful_settlements_count: 2,
      failed_settlements_count: 1,
      currency: "KES"
    )
    expect(summary.last_settled_at).to be_present
  end
end

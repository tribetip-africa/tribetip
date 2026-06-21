# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Metrics::CreatorSummary do
  it "summarizes paid, pending, and recent tips for a creator" do
    tribe = create_onboarded_tribe(username: "metrics_creator")
    tribe.tips.create!(
      amount_cents: 50_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_paid_1",
      supporter_email: "fan@example.com",
      paid_at: 2.days.ago
    )
    tribe.tips.create!(
      amount_cents: 25_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_paid_2",
      supporter_email: "fan2@example.com",
      paid_at: 10.days.ago
    )
    tribe.tips.create!(
      amount_cents: 10_000,
      currency: "KES",
      status: "pending",
      paystack_reference: "tip_pending_1",
      supporter_email: "fan3@example.com"
    )
    tribe.tips.create!(
      amount_cents: 5_000,
      currency: "KES",
      status: "failed",
      paystack_reference: "tip_failed_1",
      supporter_email: "fan4@example.com"
    )

    summary = described_class.call(tribe.reload)

    expect(summary).to have_attributes(
      paid_tips_count: 2,
      pending_tips_count: 1,
      failed_tips_count: 1,
      total_earned_cents: 75_000,
      pending_tips_cents: 10_000,
      tips_last_30_days_count: 2,
      tips_last_30_days_cents: 75_000,
      currency: "KES"
    )
    expect(summary.last_paid_at).to be_present
  end
end

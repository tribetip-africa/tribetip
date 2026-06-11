# frozen_string_literal: true

require "rails_helper"

RSpec.describe Paystack::SyncSettlementsJob, type: :job do
  it "refreshes settlement records for onboarded creators" do
    tribe = Tribe.create!(
      email: "sync@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "sync_settlements",
      country_code: "KE",
      currency: "KES"
    )
    complete_stub_paystack_onboarding!(tribe)
    tribe.tips.create!(
      amount_cents: 50_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_sync_job",
      supporter_email: "fan@example.com",
      paid_at: 1.day.ago
    )

    expect do
      described_class.perform_now
    end.to change { tribe.reload.paystack_settlements.count }.by(1)
  end
end

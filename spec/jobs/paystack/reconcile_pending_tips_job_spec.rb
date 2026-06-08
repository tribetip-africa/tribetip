# frozen_string_literal: true

require "rails_helper"

RSpec.describe Paystack::ReconcilePendingTipsJob, type: :job do
  include ActiveJob::TestHelper

  def create_pending_tip(reference:, created_at:)
    tribe = Tribe.create!(
      email: "sweep@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "sweep_creator"
    )
    complete_stub_paystack_onboarding!(tribe)

    tribe.tips.create!(
      amount_cents: 50_000,
      currency: "NGN",
      status: "pending",
      paystack_reference: reference,
      supporter_email: "fan@tribetip.africa",
      created_at: created_at,
      updated_at: created_at
    )
  end

  it "reconciles stale pending tips" do
    tip = create_pending_tip(reference: "tip_sweep_old", created_at: 20.minutes.ago)

    described_class.perform_now

    expect(tip.reload).to be_paid
    expect(tip.paid_via).to eq("sweep")
  end

  it "skips recent pending tips" do
    tip = create_pending_tip(reference: "tip_sweep_recent", created_at: 5.minutes.ago)

    described_class.perform_now

    expect(tip.reload).to be_pending
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe Paystack::ProcessWebhookJob, type: :job do
  include ActiveJob::TestHelper

  def create_tip(reference:)
    tribe = Tribe.create!(
      email: "job_webhook@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "job_webhook_creator"
    )
    tribe.tips.create!(
      amount_cents: 50_000,
      currency: "NGN",
      status: "pending",
      paystack_reference: reference,
      supporter_email: "fan@tribetip.africa"
    )
  end

  it "processes a registered webhook event" do
    tip = create_tip(reference: "tip_job_webhook")
    event = PaystackEvent.create!(
      event_id: "paystack:charge.success:tip_job_webhook",
      event_type: "charge.success",
      payload: { "event" => "charge.success", "data" => { "reference" => "tip_job_webhook" } },
      status: "pending"
    )

    described_class.perform_now(event.id)

    expect(event.reload).to be_processed
    expect(tip.reload.status).to eq("paid")
    expect(tip.paid_via).to eq("webhook")
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::ReconcilePlatform do
  def create_creator(username:)
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

  it "auto-repairs stale pending tips and caches a clean report" do
    tribe = create_creator(username: "platform_repair")
    tip = tribe.tips.create!(
      amount_cents: 50_000,
      currency: "KES",
      status: "pending",
      paystack_reference: "tip_platform_repair",
      supporter_email: "fan@tribetip.africa",
      created_at: 20.minutes.ago,
      updated_at: 20.minutes.ago
    )

    report = described_class.call(auto_repair: true)

    expect(tip.reload).to be_paid
    expect(report.repairs.fetch(:pending_tips_reconciled)).to eq(1)
    expect(report.findings).to be_empty
    expect(report.summary.fetch(:findings_count)).to eq(0)
  end

  it "raises payment alerts for stale pending tips that cannot be repaired" do
    tribe = create_creator(username: "platform_stale")
    tribe.tips.create!(
      amount_cents: 50_000,
      currency: "KES",
      status: "pending",
      paystack_reference: "tip_platform_stale",
      supporter_email: "fan@tribetip.africa",
      created_at: 20.minutes.ago,
      updated_at: 20.minutes.ago
    )

    allow(Tribetip::Paystack::ReconcileTipPayment).to receive(:call).and_return(
      Tribetip::Paystack::ReconcileTipPayment::Result.new(success?: false, message: "still pending")
    )

    expect do
      described_class.call(auto_repair: true)
    end.to change(PaymentAlert, :count).by(1)

    alert = PaymentAlert.last
    expect(alert.kind).to eq("stale_pending_tips")
    expect(alert.metadata["audit_key"]).to eq("platform:stale_pending_tips")
  end

  it "alerts when paid tips have no linked settlement after the grace period" do
    tribe = create_creator(username: "platform_unsettled")
    tribe.tips.create!(
      amount_cents: 50_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_platform_unsettled",
      supporter_email: "fan@tribetip.africa",
      paid_at: 3.days.ago,
      paid_via: "webhook"
    )

    report = described_class.call(auto_repair: false)

    finding = report.findings.find { |entry| entry.kind == "unsettled_paid_tip" }
    expect(finding).to be_present
    expect(finding.metadata["username"]).to eq("platform_unsettled")
  end

  it "alerts on failed webhook backlog" do
    PaystackEvent.create!(
      event_id: "paystack:charge.success:platform_backlog",
      event_type: "charge.success",
      status: "failed",
      payload: { "event" => "charge.success", "data" => { "reference" => "platform_backlog" } },
      error_message: "temporary failure",
      created_at: 1.hour.ago
    )

    report = described_class.call(auto_repair: false)

    expect(report.findings.map(&:kind)).to include("webhook_backlog")
  end
end

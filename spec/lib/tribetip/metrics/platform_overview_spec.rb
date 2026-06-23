# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Metrics::PlatformOverview do
  it "returns platform-wide account and tip metrics" do
    Tribe.create!(
      email: "metrics_admin@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "metrics_admin",
      role: "admin",
      account_status: "active"
    )
    creator = Tribe.create!(
      email: "metrics_creator@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "metrics_creator_user",
      display_name: "Metrics Creator",
      account_status: "active",
      is_profile_public: true,
      paystack_customer_code: "cus_metrics",
      paystack_subaccount_code: "acct_metrics",
      onboarding_completed_at: Time.current
    )
    creator.tips.create!(
      amount_cents: 40_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_platform_paid",
      supporter_email: "fan@example.com",
      paid_at: Time.current
    )
    creator.tips.create!(
      amount_cents: 15_000,
      currency: "KES",
      status: "pending",
      paystack_reference: "tip_platform_pending",
      supporter_email: "fan2@example.com"
    )

    overview = described_class.call

    expect(overview[:total_tribes]).to be >= 2
    expect(overview[:paid_tips]).to be >= 1
    expect(overview[:pending_tips]).to be >= 1
    expect(overview[:paid_volume_cents]["KES"]).to be >= 40_000
    expect(overview[:pending_volume_cents]["KES"]).to be >= 15_000
    expect(overview[:published_profiles]).to be >= 1
    expect(overview[:onboarding_complete]).to be >= 1
    expect(overview[:payout_linked]).to be >= 1
  end

  it "includes payment operations metrics" do
    overview = described_class.call

    expect(overview[:unresolved_payment_alerts]).to be_a(Integer)
    expect(overview[:failed_webhooks]).to be_a(Integer)
    expect(overview[:reconciliation][:never_run]).to be_in([ true, false ])
  end

  it "includes reconciliation summary from cache when available" do
    cached_report = {
      checked_at: Time.current.iso8601,
      summary: {
        findings_count: 2,
        critical_count: 1,
        warning_count: 1
      }
    }
    allow(Tribetip::SecureCache).to receive(:read).with(
      Tribetip::Paystack::ReconcilePlatform::REPORT_CACHE_KEY,
      scope: :private
    ).and_return(cached_report)

    overview = described_class.call

    expect(overview[:reconciliation]).to include(
      never_run: false,
      findings_count: 2,
      critical_count: 1,
      warning_count: 1
    )
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::AuditOnboarding do
  it "reports a healthy audit when Paystack resources verify" do
    tribe = create_tribe(account_status: "active", username: "audit_complete")
    complete_stub_paystack_onboarding!(tribe)

    report = described_class.call(tribe)

    expect(report).to have_attributes(
      customer_ready: true,
      subaccount_ready: true,
      onboarding_complete: true,
      healthy: true
    )
    expect(report.checks.map(&:name)).to include(
      "customer_code_present",
      "customer_paystack_verified",
      "subaccount_code_present",
      "subaccount_paystack_verified",
      "onboarding_complete"
    )
  end

  it "reports unhealthy audits when Paystack codes are missing" do
    tribe = create_tribe(account_status: "active", username: "audit_missing")
    tribe.update_columns(
      paystack_customer_code: nil,
      paystack_subaccount_code: nil,
      onboarding_completed_at: Time.current
    )

    report = described_class.call(tribe.reload)

    expect(report.healthy).to be(false)
    expect(report.onboarding_complete).to be(false)
    expect(report.local[:onboarding_completed_at]).to be_present
    expect(report.checks.find { |check| check.name == "onboarding_complete" }.status).to eq(:failed)
  end

  it "skips subaccount checks for unsupported markets" do
    tribe = create_tribe(account_status: "active", username: "audit_ci", country_code: "CI")

    report = described_class.call(tribe)

    expect(report.healthy).to be(true)
    expect(report.subaccount_ready).to be(false)
    expect(report.onboarding_complete).to be(false)
    expect(report.checks.find { |check| check.name == "subaccount_region_supported" }.status).to eq(:skipped)
  end

  it "reports healthy unsupported markets without Paystack customer codes" do
    tribe = create_tribe(account_status: "active", username: "audit_ci_live", country_code: "CI")
    tribe.update_columns(paystack_customer_code: nil, paystack_subaccount_code: nil)

    report = described_class.call(tribe.reload)

    expect(report.healthy).to be(true)
    expect(report.customer_ready).to be(false)
    expect(report.checks.find { |check| check.name == "customer_paystack_required" }.status).to eq(:skipped)
  end

  it "reconciles onboarding completion when sync is enabled" do
    tribe = create_tribe(account_status: "active", username: "audit_sync")
    complete_stub_paystack_onboarding!(tribe)
    tribe.update_columns(onboarding_completed_at: nil)

    report = described_class.call(tribe.reload, sync: true)

    expect(report.onboarding_complete).to be(true)
    expect(tribe.reload.onboarding_completed_at).to be_present
  end

  it "caches Paystack verification responses for repeated audits" do
    tribe = create_tribe(account_status: "active", username: "audit_cache")
    complete_stub_paystack_onboarding!(tribe)

    client = instance_double(Tribetip::Paystack::Client)
    allow(Tribetip::Paystack::Client).to receive(:new).and_return(client)
    verified = instance_double(
      Tribetip::Paystack::Client::ResourceResponse,
      success?: true,
      message: "Verified",
      data: { "is_verified" => true }
    )
    allow(client).to receive_messages(stub_mode?: false, fetch_customer: verified, fetch_subaccount: verified)

    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    begin
      2.times { described_class.call(tribe) }
    ensure
      Rails.cache = original_cache
    end

    expect(client).to have_received(:fetch_customer).once
    expect(client).to have_received(:fetch_subaccount).once
  end

  it "serializes audit reports for API responses" do
    tribe = create_tribe(account_status: "active", username: "audit_json")
    complete_stub_paystack_onboarding!(tribe)

    report = described_class.call(tribe)

    expect(report.as_json).to include(
      username: "audit_json",
      healthy: true,
      customer_ready: true,
      subaccount_ready: true,
      onboarding_complete: true
    )
    expect(report.as_json[:checks]).to all(include(:name, :status, :message))
  end
end

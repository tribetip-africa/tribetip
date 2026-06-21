# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::SyncOnboarding do
  it "marks onboarding complete when both Paystack resources verify" do
    tribe = create_tribe(account_status: "active", username: "sync_complete")
    complete_stub_paystack_onboarding!(tribe)

    status = described_class.call(tribe)

    expect(status).to have_attributes(customer_ready: true, subaccount_ready: true, complete: true)
    expect(tribe.reload.onboarding_completed_at).to be_present
  end

  it "does not provision customers synchronously" do
    tribe = create_tribe(account_status: "active", username: "sync_provision")
    tribe.update_columns(
      paystack_customer_code: nil,
      paystack_subaccount_code: nil,
      onboarding_completed_at: nil
    )

    status = described_class.call(tribe.reload)

    expect(status.customer_ready).to be(false)
    expect(tribe.reload.paystack_customer_code).to be_nil
  end

  it "keeps onboarding incomplete until subaccount is linked" do
    tribe = create_tribe(account_status: "active", username: "sync_incomplete")
    tribe.update_columns(
      paystack_subaccount_code: nil,
      onboarding_completed_at: Time.current
    )

    status = described_class.call(tribe.reload)

    expect(status.customer_ready).to be(true)
    expect(status.subaccount_ready).to be(false)
    expect(status.complete).to be(false)
    expect(tribe.reload.onboarding_completed_at).to be_nil
  end

  it "includes verification checks in API responses" do
    tribe = create_tribe(account_status: "active", username: "sync_verification")
    complete_stub_paystack_onboarding!(tribe)

    status = described_class.call(tribe)

    expect(status.verification).to be_present
    expect(status.as_json).to include(
      customer_ready: true,
      subaccount_ready: true,
      complete: true,
      verification: status.verification
    )
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::ReconcileTipPayment do
  def create_tip(reference:, subaccount_code: "ACCT_creator")
    tribe = Tribe.new(
      email: "reconcile@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "reconcile_creator",
      display_name: "Creator",
      account_status: "active",
      is_profile_public: true
    )
    tribe.skip_confirmation!
    tribe.save!
    tribe.update!(
      paystack_customer_code: "CUS_test",
      paystack_subaccount_code: subaccount_code,
      onboarding_completed_at: Time.current
    )

    tribe.tips.create!(
      amount_cents: 50_000,
      currency: "KES",
      paystack_reference: reference,
      supporter_email: "fan@tribetip.africa",
      status: "pending"
    )
  end

  it "marks a successful Paystack transaction as paid" do
    tip = create_tip(reference: "tip_reconcile_success")
    client = instance_double(Tribetip::Paystack::Client, stub_mode?: false)
    allow(Tribetip::Paystack::Client).to receive(:new).and_return(client)
    allow(client).to receive(:verify_transaction).and_return(
      Tribetip::Paystack::Client::VerifyResponse.new(
        success?: true,
        status: "success",
        subaccount_code: "ACCT_creator"
      )
    )

    result = described_class.call(tip)

    expect(result.success?).to be(true)
    expect(tip.reload).to be_paid
    expect(tip.paid_via).to eq("reconcile")
  end

  it "rejects a subaccount mismatch" do
    tip = create_tip(reference: "tip_reconcile_mismatch")
    client = instance_double(Tribetip::Paystack::Client, stub_mode?: false)
    allow(Tribetip::Paystack::Client).to receive(:new).and_return(client)
    allow(client).to receive(:verify_transaction).and_return(
      Tribetip::Paystack::Client::VerifyResponse.new(
        success?: true,
        status: "success",
        subaccount_code: "ACCT_other"
      )
    )

    expect { described_class.call(tip) }.to raise_error(Tribetip::Errors::BadRequest)
    expect(tip.reload).to be_pending
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::ProcessEvent do
  def create_tip(reference:, subaccount_code: "ACCT_creator")
    tribe = Tribe.new(
      email: "process_event@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "process_event_creator",
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

  it "reconciles successful charges through Paystack verification" do
    tip = create_tip(reference: "tip_process_event_success")
    client = instance_double(Tribetip::Paystack::Client, stub_mode?: false)
    allow(Tribetip::Paystack::Client).to receive(:new).and_return(client)
    allow(client).to receive(:verify_transaction).and_return(
      Tribetip::Paystack::Client::VerifyResponse.new(
        success?: true,
        status: "success",
        subaccount_code: "ACCT_creator"
      )
    )

    described_class.call({
      "event" => "charge.success",
      "data" => { "reference" => "tip_process_event_success" }
    })

    expect(tip.reload).to be_paid
    expect(tip.paid_via).to eq("webhook")
  end
end

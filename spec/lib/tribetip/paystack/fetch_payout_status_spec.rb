# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::FetchPayoutStatus do
  def create_tribe(username:, country_code: "KE", account_status: "active")
    Tribe.create!(
      email: "#{username}@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: username,
      country_code: country_code,
      account_status: account_status
    ).reload
  end

  it "reports verified stub payout status when subaccount is linked" do
    tribe = create_tribe(username: "payout_stub")
    complete_stub_paystack_onboarding!(tribe)

    status = described_class.call(tribe.reload)

    expect(status.subaccount_verified).to be(true)
    expect(status.can_publish).to be(true)
    expect(status.publish_blocker).to be_nil
    expect(status.settlement_bank).to be_present
  end

  it "blocks publishing when Paystack has not verified the subaccount" do
    tribe = create_tribe(username: "payout_unverified")
    complete_stub_paystack_onboarding!(tribe)

    client = instance_double(Tribetip::Paystack::Client)
    allow(Tribetip::Paystack::Client).to receive(:new).and_return(client)
    allow(client).to receive(:stub_mode?).and_return(false)
    allow(client).to receive(:fetch_subaccount).and_return(
      Tribetip::Paystack::Client::ResourceResponse.new(
        success?: true,
        code: tribe.paystack_subaccount_code,
        message: "OK",
        data: {
          "is_verified" => false,
          "settlement_bank" => "MPESA",
          "account_number" => "0712345678",
          "currency" => "KES"
        }
      )
    )
    allow(client).to receive(:fetch_transaction_totals).and_return(
      Tribetip::Paystack::Client::ResourceResponse.new(
        success?: true,
        code: nil,
        message: "OK",
        data: {
          "pending_transfers" => 50_000,
          "total_transactions" => 1,
          "total_volume" => 50_000
        }
      )
    )

    status = described_class.call(tribe.reload)

    expect(status.subaccount_verified).to be(false)
    expect(status.can_publish).to be(false)
    expect(status.publish_blocker).to match(/verifying/i)
    expect(status.pending_settlement_cents).to eq(50_000)
    expect(status.account_number).to match(/5678\z/)
  end
end

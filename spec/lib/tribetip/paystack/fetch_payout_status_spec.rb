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
    allow(client).to receive_messages(
      stub_mode?: false,
      fetch_subaccount: Tribetip::Paystack::Client::ResourceResponse.new(
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

    status = described_class.call(tribe.reload)

    expect(status.subaccount_verified).to be(false)
    expect(status.can_publish).to be(false)
    expect(status.publish_blocker).to match(/verifying/i)
    expect(status.pending_settlement_cents).to be_nil
    expect(status.total_transactions).to be_nil
    expect(status.total_volume_cents).to be_nil
    expect(status.account_number).to match(/5678\z/)
  end

  it "reports earnings from the creator's own tips, not merchant-wide Paystack totals" do
    tribe = create_tribe(username: "payout_owner")
    other = create_tribe(username: "payout_other")
    complete_stub_paystack_onboarding!(tribe)
    complete_stub_paystack_onboarding!(other)

    tribe.tips.create!(
      amount_cents: 50_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_payout_owner",
      supporter_email: "fan@tribetip.africa",
      paid_at: Time.current
    )
    other.tips.create!(
      amount_cents: 100_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_payout_other",
      supporter_email: "fan2@tribetip.africa",
      paid_at: Time.current
    )

    client = instance_double(Tribetip::Paystack::Client)
    allow(Tribetip::Paystack::Client).to receive(:new).and_return(client)
    allow(client).to receive_messages(
      stub_mode?: false,
      fetch_subaccount: Tribetip::Paystack::Client::ResourceResponse.new(
        success?: true,
        code: tribe.paystack_subaccount_code,
        message: "OK",
        data: {
          "is_verified" => true,
          "settlement_bank" => "MPESA",
          "account_number" => "0712345678",
          "currency" => "KES"
        }
      ),
      fetch_transaction_totals: Tribetip::Paystack::Client::ResourceResponse.new(
        success?: true,
        code: nil,
        message: "OK",
        data: {
          "pending_transfers" => 150_000,
          "total_transactions" => 99,
          "total_volume" => 9_999_999
        }
      )
    )

    status = described_class.call(tribe.reload)

    expect(status.total_transactions).to eq(1)
    expect(status.total_volume_cents).to eq(50_000)
    expect(status.available_to_settle_cents).to eq(Tribetip::Paystack::SettlementRecord.net_settlement_cents(50_000))
  end
end

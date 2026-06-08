# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::ProvisionSubaccount do
  def create_tribe(username:, country_code: "NG")
    market = Tribetip::Paystack::Market.find(country_code)
    tribe = Tribe.create!(
      email: "#{username}@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: username,
      country_code: country_code,
      currency: market.currency
    )
    tribe.update_columns(
      paystack_customer_code: "cus_existing_#{username}",
      paystack_subaccount_code: nil,
      onboarding_completed_at: nil
    )
    tribe.reload
  end

  it "creates a stub subaccount when bank details are provided" do
    tribe = create_tribe(username: "subaccount_user")

    result = described_class.call(
      tribe,
      settlement_bank: "057",
      account_number: "0123456789",
      business_name: "Subaccount User"
    )

    expect(result.success?).to be(true)
    expect(tribe.reload.paystack_subaccount_code).to be_present
    expect(tribe.paystack_onboarding_complete?).to be(true)
  end

  it "uses Kenya market stub defaults in development mode" do
    tribe = create_tribe(username: "subaccount_ke", country_code: "KE")

    result = described_class.call(tribe, settlement_bank: nil, account_number: nil)

    expect(result.success?).to be(true)
    expect(tribe.reload.paystack_subaccount_code).to be_present
  end

  it "returns an error when bank details are missing in production mode" do
    tribe = create_tribe(username: "subaccount_prod")
    client = instance_double(Tribetip::Paystack::Client, stub_mode?: false)
    allow(Tribetip::Paystack::Client).to receive(:new).and_return(client)

    result = described_class.call(tribe, settlement_bank: nil, account_number: nil)

    expect(result.success?).to be(false)
    expect(result.message).to include("Settlement bank and account number are required")
  end

  it "returns the existing subaccount code without creating a duplicate" do
    tribe = create_tribe(username: "subaccount_existing")
    tribe.update!(paystack_subaccount_code: "acct_existing_code")

    result = described_class.call(
      tribe,
      settlement_bank: "057",
      account_number: "0123456789"
    )

    expect(result.success?).to be(true)
    expect(result.subaccount_code).to eq("acct_existing_code")
  end
end

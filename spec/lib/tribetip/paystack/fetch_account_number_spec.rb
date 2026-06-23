# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::FetchAccountNumber do
  it "returns the stub account number in stub mode" do
    tribe = create_onboarded_tribe(username: "account_number_stub")

    expect(described_class.call(tribe)).to eq("0000000000")
  end

  it "returns the Paystack subaccount account number in live mode" do
    tribe = create_onboarded_tribe(username: "account_number_live")
    client = instance_double(Tribetip::Paystack::Client, stub_mode?: false)
    allow(Tribetip::Paystack::Client).to receive(:new).and_return(client)
    allow(client).to receive(:fetch_subaccount).with(tribe.paystack_subaccount_code).and_return(
      Tribetip::Paystack::Client::ResourceResponse.new(
        success?: true,
        code: tribe.paystack_subaccount_code,
        message: "ok",
        data: { "account_number" => "0712345678" }
      )
    )

    expect(described_class.call(tribe)).to eq("0712345678")
  end

  it "falls back to the market stub account for seeded subaccount codes" do
    tribe = create_onboarded_tribe(username: "account_number_seed")
    tribe.update!(paystack_subaccount_code: "acct_seed_demo")
    client = instance_double(Tribetip::Paystack::Client, stub_mode?: false)
    allow(Tribetip::Paystack::Client).to receive(:new).and_return(client)
    allow(client).to receive(:fetch_subaccount)

    expect(described_class.call(tribe)).to eq("0000000000")
    expect(client).not_to have_received(:fetch_subaccount)
  end
end

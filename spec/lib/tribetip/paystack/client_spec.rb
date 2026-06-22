# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::Client do
  subject(:client) { described_class.new(secret_key: "") }

  def stub_checkout(reference: "tip_stub_ref", subaccount: nil)
    client.initialize_transaction(
      email: "fan@tribetip.africa",
      amount_cents: 50_000,
      currency: "NGN",
      reference: reference,
      callback_url: "http://localhost:3000/creator?tip=success",
      metadata: {},
      subaccount: subaccount
    )
  end

  it "returns stub checkout data when secret key is missing" do
    response = stub_checkout

    expect(response.success?).to be(true)
    expect(response.authorization_url).to include("tip_stub_ref")
  end

  it "accepts webhook signatures in test stub mode when signature is present" do
    expect(client.verify_webhook_signature('{"event":"charge.success"}', "test-signature")).to be(true)
  end

  it "creates stub customer resources when secret key is missing" do
    customer = client.create_customer(
      email: "creator@tribetip.africa",
      first_name: "Creator",
      metadata: { tribe_id: "123" }
    )

    expect(customer.success?).to be(true)
    expect(customer.code).to start_with("cus_stub_")
    expect(client.fetch_customer(customer.code).success?).to be(true)
  end

  def stub_subaccount_params
    {
      business_name: "Creator",
      settlement_bank: "057",
      account_number: "0123456789",
      percentage_charge: 5,
      primary_contact_email: "creator@tribetip.africa",
      currency: "NGN",
      metadata: { paystack_customer_code: "cus_stub_test" }
    }
  end

  it "creates stub subaccount resources when secret key is missing" do
    subaccount = client.create_subaccount(**stub_subaccount_params)

    expect(subaccount.success?).to be(true)
    expect(subaccount.code).to start_with("acct_stub_")
    expect(client.fetch_subaccount(subaccount.code).success?).to be(true)
  end

  it "passes subaccount code when initializing checkout" do
    response = stub_checkout(reference: "tip_subaccount_ref", subaccount: "acct_stub_test")

    expect(response.success?).to be(true)
    expect(response.authorization_url).to include("tip_subaccount_ref")
  end

  describe ".rate_limited_response?" do
    it "detects Paystack rate limit messages and HTTP 429 responses" do
      expect(described_class.rate_limited_message?("Rate limit exceeded!")).to be(true)
      expect(described_class.rate_limited_response?({ "_http_status" => 429, "message" => "slow down" })).to be(true)
      expect(described_class.rate_limited_response?({ "_http_status" => 200, "message" => "ok" })).to be(false)
    end
  end

  it "lists stub banks for a Paystack bank country" do
    response = client.list_banks(paystack_bank_country: "kenya")

    expect(response.success?).to be(true)
    expect(response.data.first["name"]).to eq("KCB Bank")
    expect(response.data.first["code"]).to eq("68")
  end
end

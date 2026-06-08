# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::SettlementAccount do
  it "detects M-Pesa mobile money bank codes" do
    expect(described_class.mobile_money_bank?("MPESA")).to be(true)
    expect(described_class.mobile_money_bank?("057")).to be(false)
  end

  it "normalizes Kenyan Safaricom numbers for M-Pesa settlement" do
    expect(
      described_class.normalize(
        account_number: "254712345678",
        settlement_bank: "MPESA"
      )
    ).to eq("0712345678")

    expect(
      described_class.normalize(
        account_number: "712345678",
        settlement_bank: "MPESA"
      )
    ).to eq("0712345678")

    expect(
      described_class.normalize(
        account_number: "0712345678",
        settlement_bank: "MPESA"
      )
    ).to eq("0712345678")
  end

  it "leaves bank account numbers unchanged" do
    expect(
      described_class.normalize(
        account_number: "0123456789",
        settlement_bank: "057"
      )
    ).to eq("0123456789")
  end
end

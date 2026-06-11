# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::ListSettlementBanks do
  it "returns stub banks for supported markets" do
    market = Tribetip::Paystack::Market.find("KE")
    banks = described_class.call(market)

    expect(banks.map { |bank| bank.as_json(market: market) }).to contain_exactly(
      { name: "KCB Bank", code: "68", type: "kepss", currency: "KES", mobile_money: false },
      { name: "M-PESA", code: "MPESA", type: "mobile_money", currency: "KES", mobile_money: true }
    )
  end

  it "returns only bank transfers for Nigeria" do
    market = Tribetip::Paystack::Market.find("NG")
    banks = described_class.call(market)

    expect(market.mobile_money_supported?).to be(false)
    expect(banks.map { |bank| bank.as_json(market: market) }).to contain_exactly(
      { name: "Zenith Bank", code: "057", type: "kepss", currency: "NGN", mobile_money: false }
    )
  end

  it "returns Ghana mobile money options when supported" do
    market = Tribetip::Paystack::Market.find("GH")
    banks = described_class.call(market)

    expect(banks.map { |bank| bank.as_json(market: market) }).to include(
      hash_including(name: "MTN Mobile Money", code: "MTN", mobile_money: true)
    )
  end

  it "returns no banks when subaccounts are unsupported" do
    market = Tribetip::Paystack::Market.find("CI")
    banks = described_class.call(market)

    expect(banks).to be_empty
  end
end

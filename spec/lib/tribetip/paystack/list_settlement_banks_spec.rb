# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::ListSettlementBanks do
  it "returns stub banks for supported markets" do
    market = Tribetip::Paystack::Market.find("KE")
    banks = described_class.call(market)

    expect(banks.map(&:as_json)).to contain_exactly(
      { name: "KCB Bank", code: "68", type: "kepss", currency: "KES", mobile_money: false },
      { name: "M-PESA", code: "MPESA", type: "mobile_money", currency: "KES", mobile_money: true }
    )
  end

  it "returns no banks when subaccounts are unsupported" do
    market = Tribetip::Paystack::Market.find("CI")
    banks = described_class.call(market)

    expect(banks).to be_empty
  end
end

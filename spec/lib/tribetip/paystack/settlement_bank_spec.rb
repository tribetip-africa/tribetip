# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::SettlementBank do
  let(:nigeria) { Tribetip::Paystack::Market.find("NG") }
  let(:kenya) { Tribetip::Paystack::Market.find("KE") }

  it "filters mobile money banks out of unsupported markets" do
    banks = described_class.list_from(
      [
        { "name" => "Zenith Bank", "code" => "057", "currency" => "NGN", "type" => "nuban" },
        { "name" => "M-PESA", "code" => "MPESA", "currency" => "KES", "type" => "mobile_money" }
      ],
      currency: "NGN",
      market: nigeria
    )

    expect(banks.map(&:code)).to eq([ "057" ])
  end

  it "keeps mobile money banks for supported markets" do
    banks = described_class.list_from(
      [
        { "name" => "KCB Bank", "code" => "68", "currency" => "KES", "type" => "kepss" },
        { "name" => "M-PESA", "code" => "MPESA", "currency" => "KES", "type" => "mobile_money" }
      ],
      currency: "KES",
      market: kenya
    )

    expect(banks.map(&:code)).to contain_exactly("68", "MPESA")
  end
end

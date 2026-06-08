# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::Market do
  def build_tribe(country_code:, currency: nil)
    market = described_class.find(country_code)
    Tribe.new(
      email: "market_#{country_code.downcase}@tribetip.africa",
      password: "securepass123",
      username: "market_#{country_code.downcase}",
      country_code: country_code,
      currency: currency || market.currency
    )
  end

  it "defines all supported African markets" do
    expect(described_class.supported_country_codes).to match_array(%w[NG GH KE ZA CI])
  end

  it "maps Kenya to KES and Paystack kenya bank country" do
    market = described_class.find("KE")

    expect(market.currency).to eq("KES")
    expect(market.paystack_bank_country).to eq("kenya")
    expect(market.subaccount_supported?).to be(true)
    expect(market.stub_settlement_bank).to eq("68")
  end

  it "flags Côte d'Ivoire subaccounts as unsupported" do
    market = described_class.find("CI")

    expect(market.currency).to eq("XOF")
    expect(market.subaccount_supported?).to be(false)
  end

  it "builds Paystack metadata from a tribe" do
    tribe = build_tribe(country_code: "KE")
    tribe.id = SecureRandom.uuid

    metadata = described_class.for_tribe(tribe).paystack_metadata_for(tribe)

    expect(metadata).to include(
      tribe_id: tribe.id,
      username: tribe.username,
      country_code: "KE",
      currency: "KES",
      paystack_bank_country: "kenya"
    )
  end

  it "raises for unknown country codes" do
    expect { described_class.find("TZ") }.to raise_error(ArgumentError, /Unsupported Paystack market/)
  end
end

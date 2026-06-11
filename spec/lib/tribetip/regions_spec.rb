# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Regions do
  around do |example|
    original = ENV.to_hash
    described_class.reset!
    example.run
  ensure
    ENV.replace(original)
    described_class.reset!
  end

  it "enables only Kenya outside test" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))

    expect(described_class.enabled_country_codes).to eq([ "KE" ])
    expect(described_class.default_country_code).to eq("KE")
    expect(described_class.default_currency).to eq("KES")
  end

  it "enables all configured markets in test" do
    expect(described_class.enabled_country_codes).to match_array(%w[CI GH KE NG ZA])
  end

  it "supports TRIBETIP_ENABLED_REGIONS overrides" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
    ENV["TRIBETIP_ENABLED_REGIONS"] = "NG,KE"

    expect(described_class.enabled_country_codes).to match_array(%w[KE NG])
  end

  it "supports per-region env flags" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
    ENV["TRIBETIP_REGION_NG_ENABLED"] = "true"

    expect(described_class.enabled?("NG")).to be(true)
    expect(described_class.enabled?("KE")).to be(true)
    expect(described_class.enabled?("GH")).to be(false)
  end

  it "serializes region metadata with enabled flags" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))

    kenya = described_class.as_json.find { |region| region[:code] == "KE" }

    expect(kenya).to include(
      code: "KE",
      name: "Kenya",
      currency: "KES",
      flag: "🇰🇪",
      enabled: true
    )
  end
end

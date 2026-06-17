# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribe do
  describe "region launch flags" do
    around do |example|
      original = ENV.to_hash
      Tribetip::Regions.reset!
      example.run
    ensure
      ENV.replace(original)
      Tribetip::Regions.reset!
    end

    def build_tribe(country_code:)
      Tribe.new(
        email: "region_#{country_code.downcase}@tribetip.africa",
        password: "securepass123",
        password_confirmation: "securepass123",
        username: "region_#{country_code.downcase}",
        country_code: country_code,
        currency: Tribetip::Paystack::Market.find(country_code).currency
      )
    end

    it "rejects sign-up for disabled regions in production-like config" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))

      tribe = build_tribe(country_code: "NG")

      expect(tribe).not_to be_valid
      expect(tribe.errors[:country_code]).to include("is not available yet")
    end

    it "allows sign-up for enabled regions" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))

      tribe = build_tribe(country_code: "KE")

      expect(tribe).to be_valid
    end
  end
end

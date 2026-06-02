require 'rails_helper'

RSpec.describe Tribe, type: :model do
  describe "devise configuration" do
    subject(:devise_modules) { described_class.devise_modules }

    it { expect(devise_modules).to include(:database_authenticatable) }
    it { expect(devise_modules).to include(:registerable) }
    it { expect(devise_modules).to include(:recoverable) }
    it { expect(devise_modules).to include(:rememberable) }
    it { expect(devise_modules).to include(:validatable) }
    it { expect(devise_modules).to include(:confirmable) }
    it { expect(devise_modules).to include(:lockable) }
    it { expect(devise_modules).to include(:trackable) }
  end

  describe "validations" do
    subject(:tribe) do
      described_class.new(
        email: "owner@tribetip.africa",
        password: "securepass123",
        username: "tribe_owner"
      )
    end

    it "is valid with email and password" do
      expect(tribe).to be_valid
    end

    it "is invalid without email" do
      tribe.email = nil

      expect(tribe).not_to be_valid
    end

    it "is invalid with an improperly formatted email" do
      tribe.email = "bad_email"

      expect(tribe).not_to be_valid
    end

    it "is invalid with a short password" do
      tribe.password = "12345"

      expect(tribe).not_to be_valid
    end

    it "normalizes username before validation" do
      tribe.username = " Tribe_Owner "
      tribe.validate

      expect(tribe.username).to eq("tribe_owner")
    end

    it "is invalid without a username" do
      tribe.username = nil

      expect(tribe).not_to be_valid
    end

    it "is invalid with an unsupported country code" do
      tribe.country_code = "TZ"

      expect(tribe).not_to be_valid
    end

    it "is invalid with an unsupported currency" do
      tribe.currency = "EUR"

      expect(tribe).not_to be_valid
    end

    it "requires positive default tip amount" do
      tribe.default_tip_amount_cents = 0

      expect(tribe).not_to be_valid
    end

    it "requires display_name when profile is public" do
      tribe.is_profile_public = true

      expect(tribe).not_to be_valid
    end
  end
end

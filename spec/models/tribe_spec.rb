require 'rails_helper'

RSpec.describe Tribe, type: :model do
  describe "devise configuration" do
    subject(:devise_modules) { described_class.devise_modules }

    it { expect(devise_modules).to include(:database_authenticatable) }
    it { expect(devise_modules).to include(:registerable) }
    it { expect(devise_modules).to include(:recoverable) }
    it { expect(devise_modules).to include(:rememberable) }
    it { expect(devise_modules).to include(:validatable) }
  end

  describe "validations" do
    subject(:tribe) { described_class.new(email: "owner@tribetip.africa", password: "securepass123") }

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
  end
end

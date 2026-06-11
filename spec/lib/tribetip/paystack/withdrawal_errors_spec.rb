# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::WithdrawalErrors do
  describe ".starter_business?" do
    it "detects Paystack starter business transfer errors" do
      message = "You cannot initiate third party payouts as a starter business"

      expect(described_class.starter_business?(message)).to be(true)
    end

    it "returns false for unrelated errors" do
      expect(described_class.starter_business?("Insufficient balance")).to be(false)
    end
  end

  describe ".friendly_message" do
    it "maps starter business errors to a creator-friendly message" do
      message = described_class.friendly_message("You cannot initiate third party payouts as a starter business")

      expect(message).to include("Registered Business")
      expect(message).to include("automatically")
    end
  end
end

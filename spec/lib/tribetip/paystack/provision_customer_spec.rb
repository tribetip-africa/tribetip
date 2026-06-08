# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::ProvisionCustomer do
  it "auto-provisions a stub Paystack customer after tribe signup" do
    tribe = Tribe.create!(
      email: "provision@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "provision_user"
    )

    expect(tribe.reload.paystack_customer_code).to be_present
    expect(tribe.paystack_subaccount_code).to be_nil
    expect(tribe.paystack_onboarding_complete?).to be(false)
  end
end

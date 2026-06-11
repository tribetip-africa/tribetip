# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Seeds::Accounts do
  it "creates admin and demo creator accounts" do
    described_class.call

    superadmin = Tribe.find_by!(username: "superadmin")
    demo = Tribe.find_by!(username: "demo_creator")

    expect(superadmin).to be_admin
    expect(superadmin.account_status).to eq("active")
    expect(superadmin.paystack_customer_code).to be_nil
    expect(superadmin.paystack_subaccount_code).to be_nil
    expect(demo).to be_creator
    expect(demo.paystack_onboarding_complete?).to be(true)
    expect(demo.is_profile_public).to be(true)
    expect(demo.tips.count).to eq(3)
  end

  it "is idempotent" do
    described_class.call
    first_count = Tribe.count

    described_class.call

    expect(Tribe.count).to eq(first_count)
  end

  it "seeds Kenya market creators when Kenya is the default region" do
    described_class.call

    expect(Tribe.find_by!(username: "demo_creator").country_code).to eq("KE")
    expect(Tribe.find_by!(username: "new_creator").paystack_onboarding_complete?).to be(false)
  end
end

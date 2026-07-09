# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Referrals::ResolveCode do
  it "resolves an onboarded creator username" do
    tribe = create_creator(username: "referrer_one")

    expect(described_class.call("referrer_one")).to eq(tribe)
  end

  it "normalizes uppercase codes" do
    tribe = create_creator(username: "referrer_two")

    expect(described_class.call("REFERRER_TWO")).to eq(tribe)
  end

  it "returns nil for unknown usernames" do
    expect(described_class.call("missing_creator")).to be_nil
  end

  it "returns nil for creators who have not finished onboarding" do
    create_tribe(username: "pending_referrer", account_status: "pending")

    expect(described_class.call("pending_referrer")).to be_nil
  end

  it "returns nil for suspended referrers" do
    create_creator(username: "suspended_referrer", account_status: "suspended")

    expect(described_class.call("suspended_referrer")).to be_nil
  end

  it "returns nil for invalid code formats" do
    expect(described_class.call("ab")).to be_nil
    expect(described_class.call("bad username")).to be_nil
  end
end

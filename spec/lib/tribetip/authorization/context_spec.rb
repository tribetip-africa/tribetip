# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Authorization::Context do
  let(:creator) do
    Tribe.new(
      email: "creator@tribetip.africa",
      username: "ctx_creator",
      role: "creator",
      country_code: "KE",
      account_status: "active"
    )
  end

  it "exposes subject role helpers" do
    context = described_class.new(subject: creator)

    expect(context).to be_creator
    expect(context).not_to be_admin
    expect(context).not_to be_suspended
  end

  it "reports region availability from subject country" do
    context = described_class.new(subject: creator)

    expect(context).to be_region_enabled
  end
end

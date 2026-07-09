# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Referrals::ResolveReferral do
  it "resolves an active invite token" do
    referrer = create_creator(username: "token_referrer")
    invite = Tribetip::Referrals::Invites.ensure_active!(referrer)

    resolved = described_class.call(invite.code)

    expect(resolved.referrer).to eq(referrer)
    expect(resolved.code).to eq(invite.code)
    expect(resolved.source).to eq("invite")
  end

  it "resolves a referrer username for manual entry" do
    referrer = create_creator(username: "manual_referrer")

    resolved = described_class.call("manual_referrer")

    expect(resolved.referrer).to eq(referrer)
    expect(resolved.code).to eq("manual_referrer")
    expect(resolved.source).to eq("username")
  end

  it "resolves a referrer username with a leading @" do
    referrer = create_creator(username: "at_manual_referrer")

    resolved = described_class.call("@at_manual_referrer")

    expect(resolved.referrer).to eq(referrer)
    expect(resolved.code).to eq("at_manual_referrer")
    expect(resolved.source).to eq("username")
  end

  it "returns nil for expired invite tokens" do
    referrer = create_creator(username: "expired_referrer")
    invite = Tribetip::Referrals::Invites.ensure_active!(referrer)
    invite.update!(expires_at: 1.day.ago)

    expect(described_class.call(invite.code)).to be_nil
  end
end

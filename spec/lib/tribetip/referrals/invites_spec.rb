# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Referrals::Invites do
  it "creates an invite with an expiry" do
    referrer = create_creator(username: "invite_creator")

    invite = described_class.ensure_active!(referrer)

    expect(invite.code).to be_present
    expect(invite.expires_at).to be > Time.current
    expect(described_class.signup_url(invite.code)).to include("ref=#{invite.code}")
  end

  it "rotates an invite and revokes the previous code" do
    referrer = create_creator(username: "invite_rotate_creator")
    original = described_class.ensure_active!(referrer)

    rotated = described_class.rotate!(referrer)

    expect(rotated.code).not_to eq(original.code)
    expect(original.reload.revoked_at).to be_present
    expect(described_class.resolve(original.code)).to be_nil
    expect(described_class.resolve(rotated.code)).to eq(rotated)
  end

  it "does not create invites when referrals are turned off for the creator" do
    referrer = create_creator(username: "invite_disabled_creator", referrals_enabled: false)

    expect(described_class.ensure_active!(referrer)).to be_nil
    expect(referrer.referral_invites.count).to eq(0)
    expect(described_class.rotate!(referrer)).to be_nil
  end
end

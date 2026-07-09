# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Creator referrals", type: :request do
  it "returns referral link and stats for the signed-in creator" do
    tribe = create_creator(username: "referral_dashboard")

    get "/me/referrals", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:ok)
    payload = json.fetch("referrals")
    link = payload.fetch("link")
    aggregate_failures do
      expect(payload.fetch("can_refer")).to be(true)
      expect(link.fetch("kind")).to eq("invite")
      expect(link.fetch("code")).to be_present
      expect(link.fetch("code")).not_to eq("referral_dashboard")
      expect(link.fetch("username_code")).to eq("referral_dashboard")
      expect(link.fetch("path")).to eq("/sign-up?ref=#{link.fetch("code")}")
      expect(link.fetch("url")).to include("/sign-up?ref=#{link.fetch("code")}")
      expect(link.fetch("expires_at")).to be_present
      expect(payload.fetch("stats")).to include(
        "pending" => 0,
        "qualified" => 0,
        "rewarded" => 0,
        "total" => 0
      )
      expect(payload.fetch("entries")).to eq([])
    end
  end

  it "lists referred creators for the referrer" do
    referrer = create_creator(username: "active_referrer")
    referred = create_tribe(username: "signed_up_friend")
    Referral.create!(
      referrer: referrer,
      referred: referred,
      referral_code_used: referrer.username,
      status: "pending"
    )

    get "/me/referrals", headers: bearer_token_for(referrer), as: :json

    expect(json.dig("referrals", "stats", "pending")).to eq(1)
    expect(json.dig("referrals", "entries")).to contain_exactly(
      include(
        "username" => "signed_up_friend",
        "status" => "pending"
      )
    )
  end

  it "requires authentication" do
    get "/me/referrals", as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it "rotates the active referral invite" do
    tribe = create_creator(username: "rotate_invite_creator")
    original = Tribetip::Referrals::Invites.ensure_active!(tribe)

    post "/me/referrals/invite/rotate", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:ok)
    rotated_code = json.dig("invite", "code")
    expect(rotated_code).to be_present
    expect(rotated_code).not_to eq(original.code)
    expect(original.reload.revoked_at).to be_present
  end

  it "does not create a new invite when disabling referrals" do
    tribe = create_creator(username: "disable_no_recreate")
    invite = Tribetip::Referrals::Invites.ensure_active!(tribe)
    original_code = invite.code

    patch "/me/referrals",
          params: { referrals: { referrals_enabled: false } },
          headers: bearer_token_for(tribe),
          as: :json

    expect(response).to have_http_status(:ok)
    expect(tribe.reload.referrals_enabled?).to be(false)
    expect(json.dig("referrals", "link", "code")).to be_nil
    expect(tribe.referral_invites.active.count).to eq(0)
    expect(invite.reload.revoked_at).to be_present

    get "/me/referrals", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:ok)
    expect(json.dig("referrals", "referrals_enabled")).to be(false)
    expect(json.dig("referrals", "link", "code")).to be_nil
    expect(json.dig("referrals", "can_refer")).to be(false)
    expect(tribe.referral_invites.active.count).to eq(0)
  end

  it "turns referrals off and revokes active invite codes" do
    tribe = create_creator(username: "disable_referrals_creator")
    invite = Tribetip::Referrals::Invites.ensure_active!(tribe)

    patch "/me/referrals",
          params: { referrals: { referrals_enabled: false } },
          headers: bearer_token_for(tribe),
          as: :json

    expect(response).to have_http_status(:ok)
    payload = json.fetch("referrals")
    expect(payload.fetch("referrals_enabled")).to be(false)
    expect(payload.fetch("can_refer")).to be(false)
    expect(payload.dig("link", "code")).to be_nil
    expect(invite.reload.revoked_at).to be_present
  end

  it "turns referrals back on and issues a fresh invite" do
    tribe = create_creator(username: "enable_referrals_creator", referrals_enabled: false)

    patch "/me/referrals",
          params: { referrals: { referrals_enabled: true } },
          headers: bearer_token_for(tribe),
          as: :json

    expect(response).to have_http_status(:ok)
    payload = json.fetch("referrals")
    expect(payload.fetch("referrals_enabled")).to be(true)
    expect(payload.fetch("can_refer")).to be(true)
    expect(payload.dig("link", "code")).to be_present
  end

  it "rejects invite rotation when referrals are turned off" do
    tribe = create_creator(username: "rotate_disabled_creator", referrals_enabled: false)

    post "/me/referrals/invite/rotate", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:unprocessable_content)
  end
end

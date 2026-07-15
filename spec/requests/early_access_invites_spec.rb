# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Early access invites", type: :request do
  def register(overrides = {})
    post "/tribes.json",
         params: {
           tribe: {
             email: "invited@tribetip.africa",
             password: "securepass123",
             password_confirmation: "securepass123",
             username: "early_creator"
           }.merge(overrides)
         },
         as: :json
  end

  describe "GET /early_access/:token" do
    it "returns email for an available invite" do
      invite = Tribetip::EarlyAccess::Invites.create!(email: "invited@tribetip.africa")

      get "/early_access/#{invite.token}"

      expect(response).to have_http_status(:ok)
      expect(json).to include("email" => "invited@tribetip.africa")
      expect(invite.reload.used_at).to be_nil
    end

    it "returns not found for used invites" do
      invite = Tribetip::EarlyAccess::Invites.create!(email: "invited@tribetip.africa")
      invite.burn!(tribe: create_creator(username: "burned_owner", email: "owner@tribetip.africa"))

      get "/early_access/#{invite.token}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /tribes with launch gating" do
    around do |example|
      previous = ENV["TRIBETIP_LAUNCH_MODE"]
      ENV["TRIBETIP_LAUNCH_MODE"] = "waitlist"
      example.run
    ensure
      if previous.nil?
        ENV.delete("TRIBETIP_LAUNCH_MODE")
      else
        ENV["TRIBETIP_LAUNCH_MODE"] = previous
      end
    end

    it "rejects signup without an invite" do
      register

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects signup when email does not match invite" do
      invite = Tribetip::EarlyAccess::Invites.create!(email: "invited@tribetip.africa")

      register(early_access_token: invite.token, email: "other@tribetip.africa", username: "other_user")

      expect(response).to have_http_status(:forbidden)
      expect(invite.reload.used_at).to be_nil
    end

    it "creates the tribe and burns the invite on success" do
      invite = Tribetip::EarlyAccess::Invites.create!(email: "invited@tribetip.africa")

      register(early_access_token: invite.token)

      expect(response).to have_http_status(:created)
      expect(invite.reload.used_at).to be_present
      expect(invite.tribe.username).to eq("early_creator")
    end

    it "allows sign-in without an invite" do
      invite = Tribetip::EarlyAccess::Invites.create!(email: "invited@tribetip.africa")
      register(early_access_token: invite.token)

      post "/tribes/sign_in.json",
           params: { tribe: { login: "invited@tribetip.africa", password: "securepass123" } },
           as: :json

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /tribes when open" do
    it "ignores invite requirement" do
      register(username: "open_mode_user", email: "open@tribetip.africa")

      expect(response).to have_http_status(:created)
    end
  end

  describe "admin early access invites" do
    let(:admin) { create_tribe(username: "ea_admin", role: "admin", account_status: "active", email: "ea_admin@tribetip.africa") }

    it "creates and lists invites" do
      post "/admin/early_access_invites",
           params: { email: "wave@tribetip.africa" },
           headers: bearer_token_for(admin),
           as: :json

      expect(response).to have_http_status(:created), -> { response.body }
      expect(json.dig("invite", "email")).to eq("wave@tribetip.africa")
      expect(json.dig("invite", "url")).to include("/early-access/")

      get "/admin/early_access_invites", headers: bearer_token_for(admin)
      expect(response).to have_http_status(:ok)
      expect(json["invites"].length).to be >= 1
    end

    it "revokes an invite" do
      invite = Tribetip::EarlyAccess::Invites.create!(email: "revoke@tribetip.africa")

      patch "/admin/early_access_invites/#{invite.id}/revoke",
            headers: bearer_token_for(admin),
            as: :json

      expect(response).to have_http_status(:ok), -> { response.body }
      expect(invite.reload.revoked_at).to be_present
    end
  end
end

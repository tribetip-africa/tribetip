# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin tribes", type: :request do
  def json
    JSON.parse(response.body)
  end

  def create_tribe(username:, role: "creator", account_status: "active")
    tribe = Tribe.new(
      email: "#{username}@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: username,
      role: role,
      account_status: account_status
    )
    tribe.skip_confirmation!
    tribe.save!
    tribe
  end

  def bearer_token_for(tribe)
    token, = Warden::JWTAuth::UserEncoder.new.call(tribe, :tribe, nil)
    { "Authorization" => "Bearer #{token}" }
  end

  let(:admin) { create_tribe(username: "platform_admin", role: "admin") }
  let(:creator) { create_tribe(username: "regular_creator") }
  let(:target) { create_tribe(username: "target_creator") }

  before do
    admin
    creator
    target
  end

  describe "GET /admin/tribes" do
    it "returns tribe overview and listings for admins" do
      get "/admin/tribes", headers: bearer_token_for(admin), as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig("overview", "total_tribes")).to be >= 3
      expect(json.dig("overview", "total_tips")).to be_a(Integer)
      expect(json.dig("overview", "paid_volume_cents")).to be_a(Hash)
      expect(json.fetch("tribes")).to be_an(Array)
      expect(json.dig("pagination", "total")).to be >= 3
      expect(json.fetch("tribes").map { |row| row["username"] }).to include("target_creator")
      expect(json.fetch("tribes").first).to include("paid_tips_count", "total_earned_cents")
    end

    it "filters tribes by username or email" do
      get "/admin/tribes?q=target_creator",
          headers: bearer_token_for(admin),
          as: :json

      expect(response).to have_http_status(:ok)
      expect(json.fetch("tribes").map { |row| row["username"] }).to eq([ "target_creator" ])
    end

    it "forbids creators from listing tribes" do
      get "/admin/tribes", headers: bearer_token_for(creator), as: :json

      expect(response).to have_http_status(:forbidden)
      expect(json.dig("error", "code")).to eq("forbidden")
    end
  end

  describe "PATCH /admin/tribes/:id/activate" do
    it "allows admins to reactivate a suspended tribe" do
      target.update!(account_status: "suspended")

      patch "/admin/tribes/#{target.id}/activate",
            headers: bearer_token_for(admin),
            as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig("tribe", "account_status")).to eq("active")
      expect(target.reload.account_status).to eq("active")
    end

    it "forbids creators from activating tribes" do
      target.update!(account_status: "suspended")

      patch "/admin/tribes/#{target.id}/activate",
            headers: bearer_token_for(creator),
            as: :json

      expect(response).to have_http_status(:forbidden)
      expect(target.reload.account_status).to eq("suspended")
    end
  end
end

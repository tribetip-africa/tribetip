# frozen_string_literal: true

require "rails_helper"

RSpec.describe "RBAC foundation", type: :request do
  def auth_header_from(response)
    authorization = response.headers["Authorization"]
    return {} if authorization.blank?

    { "Authorization" => authorization }
  end

  def sign_in_tribe(login:, password: "securepass123")
    post "/tribes/sign_in.json", params: { tribe: { login: login, password: password } }, as: :json
  end

  describe "suspended accounts" do
    before do
      create_tribe(username: "suspended_user", account_status: "suspended")
    end

    it "returns forbidden when a suspended tribe signs in" do
      sign_in_tribe(login: "suspended_user")

      expect(response).to have_http_status(:forbidden)
      expect(json.dig("error", "code")).to eq("forbidden")
      expect(json.dig("error", "message")).to eq("Account suspended.")
    end

    it "returns forbidden when a suspended tribe uses a valid JWT" do
      tribe = Tribe.find_by!(username: "suspended_user")
      target = create_tribe(username: "suspend_target", account_status: "active")
      token, = Warden::JWTAuth::UserEncoder.new.call(tribe, :tribe, nil)

      patch "/admin/tribes/#{target.id}/suspend",
            headers: { "Authorization" => "Bearer #{token}" },
            as: :json

      expect(response).to have_http_status(:forbidden)
      expect(json.dig("error", "code")).to eq("forbidden")
      expect(target.reload.account_status).to eq("active")
    end
  end

  describe "admin suspend" do
    let(:target) { create_tribe(username: "target_creator", account_status: "active") }
    let(:admin) { create_tribe(username: "platform_admin", role: "admin", account_status: "active") }
    let(:creator) { create_tribe(username: "regular_creator", account_status: "active") }

    before do
      target
      admin
      creator
    end

    def admin_token
      sign_in_tribe(login: "platform_admin")
      response.headers["Authorization"]&.delete_prefix("Bearer ") || json["token"]
    end

    def creator_token
      sign_in_tribe(login: "regular_creator")
      response.headers["Authorization"]&.delete_prefix("Bearer ") || json["token"]
    end

    it "allows admins to suspend another tribe" do
      patch "/admin/tribes/#{target.id}/suspend",
            headers: { "Authorization" => "Bearer #{admin_token}" },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig("tribe", "account_status")).to eq("suspended")
      expect(target.reload.account_status).to eq("suspended")
    end

    it "forbids creators from using admin suspend" do
      patch "/admin/tribes/#{target.id}/suspend",
            headers: { "Authorization" => "Bearer #{creator_token}" },
            as: :json

      expect(response).to have_http_status(:forbidden)
      expect(json.dig("error", "code")).to eq("forbidden")
      expect(target.reload.account_status).to eq("active")
    end

    it "forbids admins from suspending themselves" do
      patch "/admin/tribes/#{admin.id}/suspend",
            headers: { "Authorization" => "Bearer #{admin_token}" },
            as: :json

      expect(response).to have_http_status(:forbidden)
      expect(admin.reload.account_status).to eq("active")
    end
  end

  describe "auth payload" do
    def register_rbac_user
      post "/tribes.json", params: {
        tribe: {
          email: "rbac@tribetip.africa",
          password: "securepass123",
          password_confirmation: "securepass123",
          username: "rbac_user",
          country_code: "NG",
          currency: "NGN"
        }
      }, as: :json
    end

    it "includes role and account_status on sign-up" do
      register_rbac_user

      expect(response).to have_http_status(:created)
      expect(json.dig("tribe", "role")).to eq("creator")
      expect(json.dig("tribe", "account_status")).to eq("pending")
    end
  end
end

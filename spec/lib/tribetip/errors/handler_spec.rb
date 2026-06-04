# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Errors::Handler, type: :request do
  def json
    JSON.parse(response.body)
  end

  describe "validation errors" do
    it "returns structured validation errors for invalid sign-up" do
      post "/tribes.json", params: {
        tribe: {
          email: "invalid-email",
          password: "securepass123",
          password_confirmation: "securepass123",
          username: "ab"
        }
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "code")).to eq("validation_failed")
      expect(json.dig("error", "message")).to be_present
      expect(json["errors"]).to be_an(Array)
      expect(json["errors"]).not_to be_empty
    end
  end

  describe "not found errors" do
    it "returns structured not found errors for missing public profiles" do
      get "/tribes/missing_creator", as: :json

      expect(response).to have_http_status(:not_found)
      expect(json.dig("error", "code")).to eq("not_found")
      expect(json.dig("error", "message")).to be_present
    end
  end

  describe "authentication errors" do
    it "returns structured authentication errors when signing out without a session" do
      delete "/tribes/sign_out.json", as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(json.dig("error", "code")).to eq("authentication_failed")
      expect(json.dig("error", "message")).to eq("No active session.")
    end
  end

  describe "rate limit errors" do
    def create_public_tribe(username:)
      tribe = Tribe.new(
        email: "#{username}@tribetip.africa",
        password: "securepass123",
        password_confirmation: "securepass123",
        username: username,
        display_name: "Creator",
        is_profile_public: true,
        account_status: "active"
      )
      tribe.skip_confirmation!
      tribe.save!
      tribe
    end

    it "returns structured rate limit errors" do
      Rack::Attack.reset!
      create_public_tribe(username: "error_rate_limit")

      60.times { get "/tribes/error_rate_limit" }

      get "/tribes/error_rate_limit"

      expect(response).to have_http_status(429)
      expect(json.dig("error", "code")).to eq("rate_limited")
      expect(json.dig("error", "message")).to match(/too many requests/i)
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Creator public access rules", type: :request do
  def json
    JSON.parse(response.body)
  end

  def create_tribe(username:, role: "creator", **attrs)
    tribe = Tribe.new(
      email: "#{username}@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: username,
      role: role,
      account_status: "active",
      display_name: "Creator Name",
      **attrs
    )
    tribe.skip_confirmation!
    tribe.save!
    tribe
  end

  describe "GET /tribes/:username" do
    it "does not expose admin accounts as public profiles" do
      admin = create_tribe(username: "admin_public", role: "admin")
      admin.update_columns(is_profile_public: true)

      get "/tribes/admin_public", as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /tips" do
    it "rejects tips to admin accounts even if marked public in the database" do
      admin = create_tribe(username: "admin_tip_target", role: "admin")
      complete_stub_paystack_onboarding!(admin)
      admin.update_columns(is_profile_public: true, onboarding_completed_at: Time.current)

      post "/tips",
           params: {
             tip: {
               username: "admin_tip_target",
               amount_cents: 50_000,
               supporter_email: "fan@example.com"
             }
           },
           as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end

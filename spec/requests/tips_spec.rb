# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tips checkout", type: :request do
  def json
    JSON.parse(response.body)
  end

  def create_tippable_tribe(username:)
    tribe = Tribe.new(
      email: "#{username}@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: username,
      display_name: "Creator",
      account_status: "active",
      is_profile_public: true
    )
    tribe.skip_confirmation!
    tribe.save!
    complete_stub_paystack_onboarding!(tribe)
    tribe
  end

  def post_tip(username:, amount_cents: 50_000, supporter_email: "fan@tribetip.africa", **extra)
    post "/tips", params: {
      tip: { username: username, amount_cents: amount_cents, supporter_email: supporter_email, **extra }
    }, as: :json
  end

  describe "POST /tips" do
    before { create_tippable_tribe(username: "tip_creator") }

    it "creates a pending tip and returns Paystack checkout URL" do
      post_tip(username: "tip_creator", supporter_name: "Fan", message: "Keep going!")

      expect(response).to have_http_status(:created)
      expect(json.dig("tip", "status")).to eq("pending")
      expect(json.dig("tip", "authorization_url")).to be_present
      expect(Tip.count).to eq(1)
    end

    it "returns not found for unpublished creators" do
      create_tippable_tribe(username: "private_creator").update!(is_profile_public: false)

      post_tip(username: "private_creator")

      expect(response).to have_http_status(:not_found)
    end

    it "returns validation errors for invalid payloads" do
      post_tip(username: "tip_creator", amount_cents: 0, supporter_email: "not-an-email")

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "code")).to eq("validation_failed")
    end

    it "returns not found when the creator has not finished Paystack onboarding" do
      username = "tip_unready_#{SecureRandom.hex(4)}"
      tribe = create_tippable_tribe(username: username)
      tribe.update_columns(paystack_subaccount_code: nil, onboarding_completed_at: nil)

      post_tip(username: username)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /tips/:paystack_reference/reconcile" do
    it "reconciles successful payments through Paystack verification" do
      create_tippable_tribe(username: "tip_reconcile_route")
      post_tip(username: "tip_reconcile_route")
      reference = json.dig("tip", "paystack_reference")

      post "/tips/#{reference}/reconcile", as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig("tip", "status")).to eq("paid")
      expect(json.dig("tip", "paid_via")).to eq("reconcile")
    end
  end
end

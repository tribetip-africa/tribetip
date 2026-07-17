# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tips checkout", type: :request do
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

      expect(response).to have_http_status(:created).or have_http_status(:accepted)
      expect(json.dig("tip", "status")).to eq("pending")
      expect(json.fetch("tip")).not_to include("supporter_email", "supporter_name", "message")
      expect(Tip.count).to eq(1)
      if response.created?
        expect(json.dig("tip", "authorization_url")).to be_present
      end
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

    it "rejects tip amounts above the configured maximum" do
      post_tip(username: "tip_creator", amount_cents: Tribetip::TipLimits.max_cents + 1)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "code")).to eq("validation_failed")
      expect(json.dig("error", "details", "errors").join).to match(/amount/i)
    end

    it "rejects tip currency that does not match the creator market" do
      post_tip(username: "tip_creator", currency: "USD")

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "code")).to eq("validation_failed")
      expect(json.dig("error", "message")).to match(/currency/i)
    end

    it "stores the creator market currency even when currency is omitted" do
      post_tip(username: "tip_creator")

      expect(response).to have_http_status(:created).or have_http_status(:accepted)
      expect(Tip.last.currency).to eq("KES")
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
      expect(json.fetch("tip")).not_to include("supporter_email", "supporter_name", "message")
    end
  end

  describe "GET /tips/checkout/:paystack_reference" do
    it "polls checkout status and records reconcile attempts" do
      tribe = create_tippable_tribe(username: "tip_checkout_poll")
      post_tip(username: "tip_checkout_poll")
      reference = json.dig("tip", "paystack_reference")
      tip = tribe.tips.find_by!(paystack_reference: reference)

      get "/tips/checkout/#{reference}", as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig("tip", "paystack_reference")).to eq(reference)
      expect(tip.tip_events.where(action: "reconcile_attempted").count).to eq(1)
    end
  end
end

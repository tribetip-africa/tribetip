# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Paystack webhooks", type: :request do
  def json
    JSON.parse(response.body)
  end

  def create_tip(reference:)
    tribe = Tribe.new(
      email: "webhook@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "webhook_creator",
      display_name: "Webhook Creator",
      account_status: "active",
      is_profile_public: true
    )
    tribe.skip_confirmation!
    allow(Paystack::ProvisionCustomerJob).to receive(:perform_later)
    tribe.save!
    complete_stub_paystack_onboarding!(tribe)

    tribe.tips.create!(
      amount_cents: 50_000,
      currency: "NGN",
      status: "pending",
      paystack_reference: reference,
      supporter_email: "fan@tribetip.africa"
    )
  end

  def post_webhook(payload, signature:)
    post "/paystack/webhook",
         params: payload,
         headers: {
           "CONTENT_TYPE" => "application/json",
           "x-paystack-signature" => signature
         }
  end

  describe "POST /paystack/webhook" do
    it "marks a pending tip as paid on charge.success" do
      tip = create_tip(reference: "tip_webhook_paid")
      payload = { event: "charge.success", data: { reference: "tip_webhook_paid" } }.to_json

      post_webhook(payload, signature: "test-signature")

      expect(response).to have_http_status(:ok)
      expect(tip.reload.status).to eq("paid")
      expect(tip.paid_via).to eq("webhook")
    end

    it "rejects invalid signatures when Paystack secret is configured" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("PAYSTACK_SECRET_KEY").and_return("sk_test_secret")
      create_tip(reference: "tip_webhook_invalid")
      payload = { event: "charge.success", data: { reference: "tip_webhook_invalid" } }.to_json

      post_webhook(payload, signature: "bad-signature")

      expect(response).to have_http_status(:bad_request)
      expect(json.dig("error", "code")).to eq("bad_request")
    end
  end
end

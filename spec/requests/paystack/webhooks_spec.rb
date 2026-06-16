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

    it "redacts sensitive Paystack payload fields before persistence" do
      create_tip(reference: "tip_webhook_redacted")
      payload = {
        event: "charge.success",
        data: {
          reference: "tip_webhook_redacted",
          customer: { email: "fan@example.com", phone: "0712345678" },
          authorization: { authorization_code: "AUTH_secret", last4: "1234" }
        }
      }.to_json

      post_webhook(payload, signature: "test-signature")

      expect(response).to have_http_status(:ok)
      stored_payload = PaystackEvent.find_by!(event_type: "charge.success").payload
      expect(stored_payload.dig("data", "reference")).to eq("tip_webhook_redacted")
      expect(stored_payload.dig("data", "customer")).to eq("[REDACTED]")
      expect(stored_payload.dig("data", "authorization")).to eq("[REDACTED]")
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

  def create_creator(username:)
    tribe = Tribe.create!(
      email: "#{username}@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: username,
      country_code: "KE",
      currency: "KES"
    )
    complete_stub_paystack_onboarding!(tribe)
    tribe.reload
  end

  describe "transfer.success webhook" do
    it "persists settlement rows for creators" do
      tribe = create_creator(username: "transfer_webhook")
      payload = {
        event: "transfer.success",
        data: {
          transfer_code: "TRF_webhook_settlement",
          amount: 60_000,
          currency: "KES",
          status: "success",
          metadata: {
            tribe_id: tribe.id,
            subaccount_code: tribe.paystack_subaccount_code
          },
          recipient: {
            details: {
              account_number: "0712345678",
              bank_name: "M-PESA"
            }
          }
        }
      }.to_json

      post "/paystack/webhook",
           params: payload,
           headers: {
             "CONTENT_TYPE" => "application/json",
             "x-paystack-signature" => "test-signature"
           }

      expect(response).to have_http_status(:ok)
      expect(PaystackSettlement.find_by(paystack_transfer_code: "TRF_webhook_settlement")&.tribe_id).to eq(tribe.id)
    end

    it "does not create settlements or creator notifications when tribe metadata conflicts" do
      tribe_a = create_creator(username: "transfer_conflict_a")
      tribe_b = create_creator(username: "transfer_conflict_b")
      payload = {
        event: "transfer.success",
        data: {
          transfer_code: "TRF_webhook_conflict",
          amount: 60_000,
          currency: "KES",
          status: "success",
          metadata: {
            tribe_id: tribe_a.id,
            subaccount_code: tribe_b.paystack_subaccount_code
          },
          recipient: {
            details: {
              account_number: "0712345678",
              bank_name: "M-PESA"
            }
          }
        }
      }.to_json

      expect do
        post_webhook(payload, signature: "test-signature")
      end.to change(PaystackSettlement, :count).by(0)
        .and change(CreatorNotification, :count).by(0)
        .and change(PaymentAlert, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(PaystackSettlement.find_by(paystack_transfer_code: "TRF_webhook_conflict")).to be_nil
      expect(PaymentAlert.last.kind).to eq("settlement_tribe_rejected")
      expect(PaymentAlert.last.metadata["transfer_code"]).to eq("TRF_webhook_conflict")
    end
  end
end

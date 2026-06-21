# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Paystack onboarding", type: :request do

  def post_onboarding(tribe, **params)
    post "/me/paystack/onboarding",
         params: { onboarding: params },
         headers: bearer_token_for(tribe),
         as: :json
  end

  describe "GET /me/paystack/onboarding" do
    it "returns onboarding status for the authenticated tribe" do
      tribe = create_tribe(username: "onboard_creator", country_code: "NG", account_status: "active")

      get "/me/paystack/onboarding", headers: bearer_token_for(tribe), as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig("onboarding", "customer_ready")).to be(true)
      expect(json.dig("onboarding", "subaccount_ready")).to be(false)
      expect(json.dig("onboarding", "complete")).to be(false)
      expect(json.dig("onboarding", "verification")).to be_present
      expect(json.dig("payout", "subaccount_verified")).to be_in([ true, false ])
      expect(json.dig("market", "country_code")).to eq("NG")
      expect(json.dig("market", "mobile_money_supported")).to be(false)
      expect(json.fetch("banks").first).to include("name" => "Zenith Bank", "code" => "057")
      expect(json.fetch("banks")).not_to include(hash_including("code" => "MPESA"))
    end

    it "returns Kenya market banks for Kenyan creators" do
      tribe = create_tribe(username: "onboard_ke", country_code: "KE")
      tribe.update!(paystack_subaccount_code: nil, onboarding_completed_at: nil)

      get "/me/paystack/onboarding", headers: bearer_token_for(tribe), as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig("market", "currency")).to eq("KES")
      expect(json.dig("market", "mobile_money_supported")).to be(true)
      banks = json.fetch("banks")
      expect(banks.first).to include("name" => "KCB Bank", "code" => "68")
      expect(banks).to include(hash_including("name" => "M-PESA", "code" => "MPESA", "mobile_money" => true))
    end

    it "provisions a Paystack customer when missing on show" do
      tribe = create_tribe(username: "onboard_missing_customer", country_code: "KE")
      tribe.update_columns(
        paystack_customer_code: nil,
        paystack_subaccount_code: nil,
        onboarding_completed_at: nil
      )

      get "/me/paystack/onboarding", headers: bearer_token_for(tribe), as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig("onboarding", "customer_ready")).to be(true)
      expect(tribe.reload.paystack_customer_code).to be_present
    end

    it "creates a Kenya M-Pesa subaccount for a Safaricom line" do
      tribe = tribe_without_subaccount(username: "onboard_ke_mpesa")
      tribe.update!(country_code: "KE", currency: "KES")

      post_onboarding(tribe, settlement_bank: "MPESA", account_number: "0712345678")

      expect(response).to have_http_status(:ok)
      expect(json.dig("onboarding", "complete")).to be(true)
      expect(tribe.reload.paystack_subaccount_code).to be_present
    end

    it "returns no banks for unsupported markets" do
      tribe = create_tribe(username: "onboard_ci", country_code: "CI")

      get "/me/paystack/onboarding", headers: bearer_token_for(tribe), as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig("market", "subaccount_supported")).to be(false)
      expect(json.fetch("banks")).to eq([])
    end
  end

  def tribe_without_subaccount(username:)
    tribe = create_tribe(username: username)
    tribe.update!(
      paystack_customer_code: "cus_manual_#{tribe.id}",
      paystack_subaccount_code: nil,
      onboarding_completed_at: nil
    )
    tribe
  end

  describe "POST /me/paystack/onboarding" do
    it "creates a subaccount when bank details are provided" do
      tribe = tribe_without_subaccount(username: "onboard_bank")

      post_onboarding(
        tribe,
        settlement_bank: "057",
        account_number: "0123456789",
        business_name: "Onboard Creator"
      )

      expect(response).to have_http_status(:ok)
      expect(json.dig("onboarding", "complete")).to be(true)
      expect(tribe.reload.paystack_subaccount_code).to be_present
    end

    it "creates a Kenya subaccount using market bank defaults" do
      tribe = tribe_without_subaccount(username: "onboard_ke_bank")
      tribe.update!(country_code: "KE", currency: "KES")

      post_onboarding(tribe, settlement_bank: "68", account_number: "0123456789")

      expect(response).to have_http_status(:ok)
      expect(json.dig("market", "country_code")).to eq("KE")
      expect(tribe.reload.paystack_subaccount_code).to be_present
    end

    it "rejects idempotency key reuse with a different payload" do
      tribe = tribe_without_subaccount(username: "onboard_idem_payload")
      headers = bearer_token_for(tribe).merge("Idempotency-Key" => "onboarding-payload-key")

      post "/me/paystack/onboarding",
           params: { onboarding: { settlement_bank: "057", account_number: "0123456789" } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)

      tribe.update!(
        paystack_subaccount_code: nil,
        onboarding_completed_at: nil
      )

      post "/me/paystack/onboarding",
           params: { onboarding: { settlement_bank: "057", account_number: "9999999999" } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:bad_request)
      expect(json.dig("error", "message")).to match(/Idempotency-Key/)
    end
  end
end

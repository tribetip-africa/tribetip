# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Me profile", type: :request do

  describe "GET /me/profile" do
    it "requires authentication" do
      get "/me/profile", as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the authenticated creator profile" do
      tribe = create_tribe(username: "profile_show", display_name: "Creator", account_status: "active")
      complete_stub_paystack_onboarding!(tribe)
      tribe.tips.create!(
        amount_cents: 50_000,
        currency: "NGN",
        status: "paid",
        paystack_reference: "tip_profile_metric",
        supporter_email: "fan@example.com",
        paid_at: Time.current
      )

      get "/me/profile", headers: bearer_token_for(tribe), as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig("profile", "username")).to eq("profile_show")
      expect(json.dig("profile", "display_name")).to eq("Creator")
      expect(json.dig("profile", "metrics", "paid_tips_count")).to eq(1)
      expect(json.dig("profile", "metrics", "total_earned_cents")).to eq(50_000)
    end

    it "activates pending creators when Paystack onboarding is complete" do
      tribe = create_tribe(username: "profile_activate", account_status: "pending")
      tribe.update!(
        paystack_customer_code: "cus_test",
        paystack_subaccount_code: "acct_test",
        onboarding_completed_at: Time.current
      )

      get "/me/profile", headers: bearer_token_for(tribe), as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig("profile", "account_status")).to eq("active")
      expect(tribe.reload.account_status).to eq("active")
      expect(json.dig("profile", "is_profile_public")).to be(false)
    end
  end

  describe "PATCH /me/profile" do
    it "updates the authenticated creator profile" do
      tribe = create_tribe(username: "profile_update", account_status: "active")
      complete_stub_paystack_onboarding!(tribe)
      patch "/me/profile",
            params: { profile: { display_name: "Updated Name", bio: "Hello fans" } },
            headers: bearer_token_for(tribe),
            as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig("profile", "display_name")).to eq("Updated Name")
      expect(json.dig("profile", "bio")).to eq("Hello fans")
    end

    it "forbids suspended creators from updating" do
      tribe = create_tribe(username: "profile_suspended", account_status: "suspended")
      patch "/me/profile",
            params: { profile: { display_name: "Blocked" } },
            headers: bearer_token_for(tribe),
            as: :json

      expect(response).to have_http_status(:forbidden)
      expect(json.dig("error", "code")).to eq("forbidden")
    end
  end

  describe "POST /me/profile/publish" do
    it "forbids creators without completed Paystack onboarding from publishing" do
      tribe = create_tribe(username: "profile_pending", display_name: "Pending Creator")
      clear_paystack_onboarding!(tribe)

      post "/me/profile/publish", headers: bearer_token_for(tribe), as: :json

      expect(response).to have_http_status(:forbidden)
      expect(json.dig("error", "code")).to eq("onboarding_required")
      expect(tribe.reload.is_profile_public).to be(false)
    end

    it "forbids active creators without a display name" do
      tribe = create_tribe(username: "profile_no_name", account_status: "active")
      post "/me/profile/publish", headers: bearer_token_for(tribe), as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "publishes an active creator profile with a display name" do
      tribe = create_tribe(
        username: "profile_publish",
        account_status: "active",
        display_name: "Live Creator"
      )
      complete_stub_paystack_onboarding!(tribe)

      post "/me/profile/publish", headers: bearer_token_for(tribe), as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig("profile", "is_profile_public")).to be(true)
      expect(tribe.reload.is_profile_public).to be(true)
    end

    it "forbids publishing when Paystack has not verified the subaccount" do
      tribe = create_tribe(
        username: "profile_unverified",
        account_status: "active",
        display_name: "Unverified Creator"
      )
      complete_stub_paystack_onboarding!(tribe)

      client = instance_double(Tribetip::Paystack::Client)
      allow(Tribetip::Paystack::Client).to receive(:new).and_return(client)
      allow(client).to receive_messages(stub_mode?: false, fetch_subaccount: Tribetip::Paystack::Client::ResourceResponse.new(
          success?: true,
          code: tribe.paystack_subaccount_code,
          message: "OK",
          data: { "is_verified" => false, "currency" => "KES" }
        ), fetch_transaction_totals: Tribetip::Paystack::Client::ResourceResponse.new(
          success?: true,
          code: nil,
          message: "OK",
          data: { "pending_transfers" => 0, "total_transactions" => 0, "total_volume" => 0 }
        ))

      post "/me/profile/publish", headers: bearer_token_for(tribe), as: :json

      expect(response).to have_http_status(:forbidden)
      expect(json.dig("error", "code")).to eq("subaccount_not_verified")
      expect(tribe.reload.is_profile_public).to be(false)
    end

    it "forbids publishing when Paystack onboarding is incomplete" do
      tribe = create_tribe(
        username: "profile_unready",
        account_status: "active",
        display_name: "Unready Creator"
      )
      clear_paystack_onboarding!(tribe)

      post "/me/profile/publish", headers: bearer_token_for(tribe), as: :json

      expect(response).to have_http_status(:forbidden)
      expect(tribe.reload.is_profile_public).to be(false)
    end
  end
end

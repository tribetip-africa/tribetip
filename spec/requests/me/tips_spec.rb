# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Me tips", type: :request do

  def create_tip_for(tribe, reference: "tip_test_ref")
    tribe.tips.create!(
      amount_cents: 50_000,
      currency: "NGN",
      status: "paid",
      paystack_reference: reference,
      supporter_email: "fan@tribetip.africa",
      paid_at: Time.current
    )
  end

  describe "GET /me/tips" do
    it "returns tips for the authenticated creator" do
      creator = create_creator(username: "tips_creator")
      create_tip_for(creator, reference: "tip_creator_ref")

      get "/me/tips", headers: bearer_token_for(creator), as: :json

      expect(response).to have_http_status(:ok)
      expect(json.fetch("tips").length).to eq(1)
    end

    it "forbids listing another creator's tips" do
      owner = create_tribe(username: "tip_owner", account_status: "active")
      other = create_tribe(username: "tip_other", account_status: "active")
      tip = create_tip_for(owner, reference: "tip_owner_ref")

      get "/me/tips/#{tip.id}", headers: bearer_token_for(other), as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "requires Paystack onboarding before listing tips" do
      creator = create_tribe(username: "tips_unready", account_status: "active")
      creator.update_columns(
        paystack_customer_code: nil,
        paystack_subaccount_code: nil,
        onboarding_completed_at: nil
      )

      get "/me/tips", headers: bearer_token_for(creator), as: :json

      expect(response).to have_http_status(:forbidden)
      expect(json.dig("error", "code")).to eq("onboarding_required")
    end
  end
end

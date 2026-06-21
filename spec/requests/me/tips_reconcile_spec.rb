# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Creator tip reconcile", type: :request do
  it "reconciles a pending tip for the authenticated creator" do
    tribe = create_creator(username: "creator_tip_reconcile")
    tip = tribe.tips.create!(
      amount_cents: 25_000,
      currency: "KES",
      status: "pending",
      paystack_reference: "tip_creator_reconcile",
      supporter_email: "fan@example.com"
    )

    post "/me/tips/#{tip.id}/reconcile", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:ok)
    expect(json.dig("tip", "status")).to eq("paid")
    expect(json.dig("tip", "paid_via")).to eq("reconcile")
  end
end

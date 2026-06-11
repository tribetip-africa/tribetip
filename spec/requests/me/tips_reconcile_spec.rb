# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Creator tip reconcile", type: :request do
  def json
    JSON.parse(response.body)
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

  def bearer_token_for(tribe)
    token, = Warden::JWTAuth::UserEncoder.new.call(tribe, :tribe, nil)
    { "Authorization" => "Bearer #{token}" }
  end

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

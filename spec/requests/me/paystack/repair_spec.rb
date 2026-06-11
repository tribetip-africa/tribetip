# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Paystack repair", type: :request do
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

  it "syncs Paystack data for the authenticated creator" do
    tribe = create_creator(username: "repair_route")
    tribe.tips.create!(
      amount_cents: 50_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_repair_route",
      supporter_email: "fan@example.com",
      paid_at: 1.day.ago
    )

    post "/me/paystack/repair", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:ok)
    expect(json.dig("repair", "settlements_count")).to eq(1)
    expect(json.dig("repair", "settlement_summary", "successful_settlements_count")).to eq(1)
  end
end

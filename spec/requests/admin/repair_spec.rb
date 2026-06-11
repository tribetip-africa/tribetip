# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin Paystack repair", type: :request do
  def json
    JSON.parse(response.body)
  end

  def create_admin(username: "platform_admin")
    Tribe.create!(
      email: "#{username}@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: username,
      role: "admin",
      country_code: "KE",
      currency: "KES"
    )
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

  it "repairs Paystack data for a creator account" do
    admin = create_admin
    creator = create_creator(username: "admin_repair_creator")
    creator.tips.create!(
      amount_cents: 50_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_admin_repair",
      supporter_email: "fan@example.com",
      paid_at: 1.day.ago
    )

    post "/admin/tribes/#{creator.id}/repair", headers: bearer_token_for(admin), as: :json

    expect(response).to have_http_status(:ok)
    expect(json["username"]).to eq("admin_repair_creator")
    expect(json.dig("repair", "settlements_count")).to eq(1)
  end
end

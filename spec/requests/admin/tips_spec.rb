# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin tip investigation", type: :request do
  def json
    JSON.parse(response.body)
  end

  def create_admin
    Tribe.create!(
      email: "admin_tip@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "admin_tip",
      role: "admin"
    )
  end

  def auth_headers(tribe)
    post "/tribes/sign_in",
         params: { tribe: { login: tribe.email, password: "securepass123" } },
         as: :json
    token = response.headers["Authorization"]&.delete_prefix("Bearer ")
    { "Authorization" => "Bearer #{token}" }
  end

  it "returns an investigation timeline for a tip reference" do
    admin = create_admin
    tribe = Tribe.create!(
      email: "creator_tip@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "creator_tip"
    )
    tip = tribe.tips.create!(
      amount_cents: 50_000,
      currency: "NGN",
      paystack_reference: "tip_investigate_ref",
      supporter_email: "fan@tribetip.africa",
      status: "pending"
    )
    tip.record_created_event!(source: "public")

    get "/admin/tips/tip_investigate_ref/investigate",
        headers: auth_headers(admin),
        as: :json

    expect(response).to have_http_status(:ok)
    expect(json.dig("investigation", "tip", "paystack_reference")).to eq("tip_investigate_ref")
    expect(json.dig("investigation", "tip_events")).not_to be_empty
  end
end

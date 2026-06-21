# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin payment alerts", type: :request do
  def create_admin
    Tribe.create!(
      email: "admin_alerts@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "admin_alerts",
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

  it "lists payment alerts for admins" do
    admin = create_admin
    PaymentAlert.create!(
      kind: "settlement_tribe_rejected",
      title: "Settlement webhook rejected",
      body: "Rejected TRF_admin_list.",
      metadata: { transfer_code: "TRF_admin_list", reason: "tribe_id_subaccount_conflict" }
    )

    get "/admin/payment_alerts", headers: auth_headers(admin), as: :json

    expect(response).to have_http_status(:ok)
    expect(json.fetch("alerts").first.fetch("metadata").fetch("transfer_code")).to eq("TRF_admin_list")
  end

  it "rejects non-admin access" do
    creator = Tribe.create!(
      email: "creator_alerts@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "creator_alerts"
    )

    get "/admin/payment_alerts", headers: auth_headers(creator), as: :json

    expect(response).to have_http_status(:forbidden)
  end
end

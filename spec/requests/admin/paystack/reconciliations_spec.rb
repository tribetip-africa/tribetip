# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin Paystack reconciliation", type: :request do
  def create_admin
    Tribe.create!(
      email: "admin_reconcile@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "admin_reconcile",
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

  it "returns the latest cached reconciliation report" do
    admin = create_admin
    allow(Tribetip::SecureCache).to receive(:read).with(
      Tribetip::Paystack::ReconcilePlatform::REPORT_CACHE_KEY,
      scope: :private
    ).and_return(
      "checked_at" => Time.current.iso8601,
      "summary" => { "findings_count" => 0 }
    )

    get "/admin/paystack/reconciliation", headers: auth_headers(admin), as: :json

    expect(response).to have_http_status(:ok)
    expect(json.dig("reconciliation", "summary", "findings_count")).to eq(0)
  end

  it "runs reconciliation synchronously for admins" do
    admin = create_admin

    post "/admin/paystack/reconciliation",
         params: { auto_repair: false },
         headers: auth_headers(admin),
         as: :json

    expect(response).to have_http_status(:ok)
    expect(json.fetch("reconciliation").fetch("checked_at")).to be_present
  end

  it "rejects non-admin access" do
    creator = Tribe.create!(
      email: "creator_reconcile@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "creator_reconcile"
    )

    get "/admin/paystack/reconciliation", headers: auth_headers(creator), as: :json

    expect(response).to have_http_status(:forbidden)
  end
end

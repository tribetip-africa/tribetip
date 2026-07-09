# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin referrals", type: :request do
  it "returns referral funnel metrics for admins" do
    admin = create_tribe(username: "referral_admin", role: "admin", account_status: "active")
    referrer = create_creator(username: "admin_ref_referrer")
    referred = create_tribe(username: "admin_ref_referred")
    Referral.create!(
      referrer: referrer,
      referred: referred,
      referral_code_used: referrer.username,
      status: "pending"
    )

    get "/admin/referrals", headers: bearer_token_for(admin), as: :json

    expect(response).to have_http_status(:ok)
    expect(json.dig("overview", "pending")).to eq(1)
    expect(json.fetch("referrals")).to be_an(Array)
  end

  it "rejects a pending referral" do
    admin = create_tribe(username: "reject_admin", role: "admin", account_status: "active")
    referrer = create_creator(username: "reject_referrer")
    referred = create_tribe(username: "reject_referred")
    referral = Referral.create!(
      referrer: referrer,
      referred: referred,
      referral_code_used: referrer.username,
      status: "pending"
    )

    patch "/admin/referrals/#{referral.id}/reject",
          params: { reason: "Suspected self-referral" },
          headers: bearer_token_for(admin),
          as: :json

    expect(response).to have_http_status(:ok), -> { response.body }
    expect(referral.reload.status).to eq("rejected")
  end
end

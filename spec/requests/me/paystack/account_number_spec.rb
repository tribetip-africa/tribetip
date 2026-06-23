# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Paystack account number reveal", type: :request do
  it "returns the creator payout account number" do
    tribe = create_onboarded_tribe(username: "account_number_route")

    get "/me/paystack/account_number", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:ok)
    expect(json["account_number"]).to be_present
  end

  it "records an audit log without storing the full account number" do
    tribe = create_onboarded_tribe(username: "account_number_audit")

    expect do
      get "/me/paystack/account_number", headers: bearer_token_for(tribe), as: :json
    end.to change(TribeAuditLog, :count).by(1)

    expect(response).to have_http_status(:ok)
    account_number = json["account_number"]

    log = TribeAuditLog.order(created_at: :desc).first
    expect(log.tribe_id).to eq(tribe.id)
    expect(log.action).to eq("account_number_revealed")
    expect(log.request_id).to be_present
    expect(log.details.to_json).not_to include(account_number)
    expect(log.details).not_to have_key("account_number")
  end

  it "requires authentication" do
    get "/me/paystack/account_number", as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it "forbids suspended creators" do
    tribe = create_onboarded_tribe(username: "account_number_suspended", account_status: "suspended")

    get "/me/paystack/account_number", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:forbidden)
    expect(json.dig("error", "message")).to eq("Account suspended.")
    expect(TribeAuditLog.count).to eq(0)
  end

  it "forbids creators without payout setup" do
    tribe = create_tribe(username: "account_number_pending", account_status: "active")

    get "/me/paystack/account_number", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:forbidden)
    expect(TribeAuditLog.count).to eq(0)
  end

  it "requires a recent password sign-in before revealing payout account numbers" do
    tribe = create_onboarded_tribe(username: "account_number_stale_session")
    tribe.update!(last_password_authenticated_at: 20.minutes.ago)
    headers = bearer_token_for(tribe)
    tribe.update!(last_password_authenticated_at: 20.minutes.ago)

    get "/me/paystack/account_number", headers: headers, as: :json

    expect(response).to have_http_status(:forbidden)
    expect(json.dig("error", "code")).to eq("reauthentication_required")
    expect(TribeAuditLog.count).to eq(0)
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Paystack withdrawals", type: :request do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("TRIBETIP_PAYOUT_MODE", "auto").and_return("manual")
    allow(ENV).to receive(:[]).with("TRIBETIP_PAYSTACK_TRANSFERS_ENABLED").and_return("true")
    Tribetip::Paystack::FetchPayoutCapabilities.clear!
  end

  it "returns withdrawal status for onboarded creators" do
    tribe = create_creator(username: "withdraw_status")
    tribe.tips.create!(
      amount_cents: 50_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_withdraw_status",
      supporter_email: "fan@example.com",
      paid_at: 1.day.ago
    )

    get "/me/paystack/withdrawals", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:ok)
    expect(json.dig("status", "payout_mode")).to eq("manual")
    expect(json.dig("status", "effective_payout_mode")).to eq("manual")
    expect(json.dig("status", "transfers_supported")).to be(true)
    expect(json.dig("status", "available_to_withdraw_cents")).to eq(47_500)
    expect(json.dig("status", "can_withdraw")).to be(true)
  end

  it "creates a withdrawal request" do
    tribe = create_creator(username: "withdraw_create")
    tribe.tips.create!(
      amount_cents: 100_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_withdraw_create",
      supporter_email: "fan@example.com",
      paid_at: 1.day.ago
    )

    post "/me/paystack/withdrawals", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:ok)
    expect(json.dig("withdrawal", "amount_cents")).to eq(95_000)
    expect(json.dig("withdrawal", "source")).to eq("manual_withdrawal")
    expect(json.dig("status", "available_to_withdraw_cents")).to eq(0)
  end

  it "scopes idempotency keys to the authenticated creator" do
    first = create_creator(username: "withdraw_idem_first")
    second = create_creator(username: "withdraw_idem_second")

    [ first, second ].each do |tribe|
      tribe.tips.create!(
        amount_cents: 100_000,
        currency: "KES",
        status: "paid",
        paystack_reference: "tip_#{tribe.username}",
        supporter_email: "fan@example.com",
        paid_at: 1.day.ago
      )
    end

    headers = { "Idempotency-Key" => "shared-withdrawal-key" }
    post "/me/paystack/withdrawals", headers: bearer_token_for(first).merge(headers), as: :json
    first_withdrawal_id = json.dig("withdrawal", "id")

    post "/me/paystack/withdrawals", headers: bearer_token_for(second).merge(headers), as: :json

    expect(response).to have_http_status(:ok)
    expect(json.dig("withdrawal", "id")).not_to eq(first_withdrawal_id)
    expect(IdempotencyKey.where(scope: "paystack_withdrawal", key: "shared-withdrawal-key").count).to eq(2)
  end

  it "blocks manual withdrawal when Paystack transfers are unavailable" do
    tribe = create_creator(username: "withdraw_blocked")
    tribe.tips.create!(
      amount_cents: 100_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_withdraw_blocked",
      supporter_email: "fan@example.com",
      paid_at: 1.day.ago
    )

    allow(ENV).to receive(:[]).with("TRIBETIP_PAYSTACK_TRANSFERS_ENABLED").and_return("false")

    get "/me/paystack/withdrawals", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:ok)
    expect(json.dig("status", "effective_payout_mode")).to eq("auto")
    expect(json.dig("status", "can_withdraw")).to be(false)
    expect(json.dig("status", "withdraw_blocker")).to include("Registered Business")
  end
end

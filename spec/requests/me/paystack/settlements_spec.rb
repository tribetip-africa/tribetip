# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Paystack settlements", type: :request do

  it "returns settlement history for onboarded creators" do
    tribe = create_creator(username: "settlement_history")
    tribe.tips.create!(
      amount_cents: 100_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_settlement_history",
      supporter_email: "fan@example.com",
      paid_at: 1.day.ago
    )

    get "/me/paystack/settlements", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:ok)
    expect(json.fetch("settlements").first).to include(
      "amount_cents" => 95_000,
      "currency" => "KES",
      "status" => "success",
      "reference" => "tip_settlement_history",
      "source" => "sync"
    )
    expect(json["source"]).to eq("database")
    expect(json["synced_at"]).to be_present
    expect(json.dig("summary", "total_settled_cents")).to eq(95_000)
    expect(json.dig("summary", "successful_settlements_count")).to eq(1)
  end

  it "returns settlement detail with fee breakdown" do
    tribe = create_creator(username: "settlement_detail_api")
    tip = tribe.tips.create!(
      amount_cents: 100_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_detail_api",
      supporter_email: "fan@example.com",
      paid_at: 1.day.ago
    )
    get "/me/paystack/settlements", headers: bearer_token_for(tribe), as: :json
    settlement_id = json.fetch("settlements").first.fetch("id")

    get "/me/paystack/settlements/#{settlement_id}", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:ok)
    expect(json.dig("breakdown", "gross_cents")).to eq(100_000)
    expect(json.dig("breakdown", "net_cents")).to eq(95_000)
    expect(json.dig("tip", "id")).to eq(tip.id)
  end

  it "includes settlement summary in onboarding payload" do
    tribe = create_creator(username: "onboarding_settlement_summary")
    tribe.tips.create!(
      amount_cents: 100_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_onboarding_summary",
      supporter_email: "fan@example.com",
      paid_at: 1.day.ago
    )
    get "/me/paystack/settlements", headers: bearer_token_for(tribe), as: :json

    get "/me/paystack/onboarding", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:ok)
    expect(json.dig("settlements_summary", "successful_settlements_count")).to eq(1)
    expect(json.dig("settlements_summary", "total_settled_cents")).to eq(95_000)
  end

  it "includes earnings in onboarding payload" do
    tribe = create_creator(username: "earnings_payload")
    tribe.tips.create!(
      amount_cents: 50_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_earnings_payload",
      supporter_email: "fan@example.com",
      paid_at: Time.current
    )

    get "/me/paystack/onboarding", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:ok)
    expect(json.dig("earnings", "total_earned_cents")).to eq(50_000)
    expect(json.dig("payout", "available_to_settle_cents")).to be_a(Integer)
    expect(json.dig("payout", "settlement_schedule_label")).to be_present
  end
end

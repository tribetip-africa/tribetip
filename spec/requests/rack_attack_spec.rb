# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rack::Attack throttling", type: :request do
  def exhaust_public_profile_limit(username, count: 60)
    count.times { get "/tribes/#{username}" }
  end

  def create_tip(reference:)
    tribe = create_public_tribe(username: "throttle_tip_#{SecureRandom.hex(4)}")
    complete_stub_paystack_onboarding!(tribe)
    tribe.tips.create!(
      amount_cents: 50_000,
      currency: "KES",
      status: "pending",
      paystack_reference: reference,
      supporter_email: "fan@example.com"
    )
  end

  it "rate limits repeated public profile lookups" do
    Rack::Attack.reset!
    create_public_tribe(username: "throttle_me")
    exhaust_public_profile_limit("throttle_me")

    get "/tribes/throttle_me"
    expect(response).to have_http_status(429)
    body = JSON.parse(response.body)
    expect(body.dig("error", "code")).to eq("rate_limited")
    expect(body.dig("error", "message")).to match(/too many requests/i)
  end

  it "rate limits repeated public checkout polling for the same reference" do
    Rack::Attack.reset!
    tip = create_tip(reference: "tip_checkout_throttle")

    10.times { get "/tips/checkout/#{tip.paystack_reference}" }
    get "/tips/checkout/#{tip.paystack_reference}"

    expect(response).to have_http_status(429)
    body = JSON.parse(response.body)
    expect(body.dig("error", "code")).to eq("rate_limited")
  end

  it "rate limits repeated public reconciliation for the same reference" do
    Rack::Attack.reset!
    tip = create_tip(reference: "tip_reconcile_throttle")

    10.times { post "/tips/#{tip.paystack_reference}/reconcile", as: :json }
    post "/tips/#{tip.paystack_reference}/reconcile", as: :json

    expect(response).to have_http_status(429)
    body = JSON.parse(response.body)
    expect(body.dig("error", "code")).to eq("rate_limited")
  end

  it "rate limits repeated sign-in attempts on .json routes" do
    Rack::Attack.reset!

    10.times do
      post "/tribes/sign_in.json",
        params: { tribe: { login: "nobody@tribetip.africa", password: "wrong" } },
        as: :json
    end

    post "/tribes/sign_in.json",
      params: { tribe: { login: "nobody@tribetip.africa", password: "wrong" } },
      as: :json

    expect(response).to have_http_status(429)
    body = JSON.parse(response.body)
    expect(body.dig("error", "code")).to eq("rate_limited")
    expect(body.dig("error", "message")).to match(/too many requests/i)
  end
end

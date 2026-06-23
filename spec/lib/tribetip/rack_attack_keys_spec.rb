# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::RackAttackKeys do
  def build_request(method:, path:, params: {}, authorization: nil)
    env = Rack::MockRequest.env_for(
      path,
      method: method,
      params: params,
      "HTTP_AUTHORIZATION" => authorization
    )
    ActionDispatch::Request.new(env)
  end

  it "scopes public profile throttles per IP and creator username" do
    request = build_request(method: "GET", path: "/tribes/demo_creator")

    expect(described_class.profile_view(request)).to eq("profile:#{request.ip}:demo_creator")
  end

  it "scopes tip creation throttles per IP and target creator" do
    request = build_request(
      method: "POST",
      path: "/tips",
      params: { tip: { username: "demo_creator", amount_cents: 50_000 } }
    )

    expect(described_class.tip_create(request)).to eq("tip-create:#{request.ip}:demo_creator")
  end

  it "scopes checkout polling per IP and paystack reference" do
    request = build_request(method: "GET", path: "/tips/checkout/tip_abc123")

    expect(described_class.tip_checkout_poll(request)).to eq("tip-checkout:#{request.ip}:tip_abc123")
  end

  it "scopes authenticated account actions per bearer token" do
    request = build_request(method: "POST", path: "/me/paystack/withdrawals", authorization: "Bearer secret-token")

    expect(described_class.bearer_account(request)).to start_with("account:")
  end
end

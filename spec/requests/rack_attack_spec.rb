# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rack::Attack throttling", type: :request do
  def create_public_tribe(username:)
    tribe = Tribe.new(
      email: "#{username}@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: username,
      display_name: "Creator",
      is_profile_public: true,
      account_status: "active"
    )
    tribe.skip_confirmation!
    tribe.save!
    tribe
  end

  def exhaust_public_profile_limit(username, count: 60)
    count.times { get "/tribes/#{username}" }
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
end

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

  it "rate limits repeated public profile lookups" do
    Rack::Attack.reset!
    create_public_tribe(username: "throttle_me")

    60.times do |index|
      get "/tribes/throttle_me"
      expect(response.status).to eq(200), "request #{index + 1} was throttled early"
    end

    get "/tribes/throttle_me"
    expect(response).to have_http_status(429)
    expect(JSON.parse(response.body)).to include("error" => "Too many requests")
  end
end

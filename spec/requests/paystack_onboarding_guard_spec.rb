# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Paystack onboarding guards", type: :request do
  def json
    JSON.parse(response.body)
  end

  def create_tribe(username:)
    tribe = Tribe.new(
      email: "#{username}@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: username,
      account_status: "active",
      display_name: "Creator"
    )
    tribe.skip_confirmation!
    tribe.save!
    tribe
  end

  def bearer_token_for(tribe)
    token, = Warden::JWTAuth::UserEncoder.new.call(tribe, :tribe, nil)
    { "Authorization" => "Bearer #{token}" }
  end

  it "blocks dashboard profile access until Paystack onboarding is complete" do
    tribe = create_tribe(username: "guard_pending")
    tribe.update_columns(
      paystack_customer_code: nil,
      paystack_subaccount_code: nil,
      onboarding_completed_at: nil
    )

    get "/me/profile", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:forbidden)
    expect(json.dig("error", "code")).to eq("onboarding_required")
  end
end

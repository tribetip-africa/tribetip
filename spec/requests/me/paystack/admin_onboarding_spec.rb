# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Paystack onboarding for admins", type: :request do
  def create_admin(username: "paystack_admin")
    tribe = Tribe.new(
      email: "#{username}@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: username,
      role: "admin"
    )
    tribe.skip_confirmation!
    tribe.save!
    tribe
  end

  it "rejects Paystack onboarding requests for admin accounts" do
    admin = create_admin

    get "/me/paystack/onboarding", headers: bearer_token_for(admin), as: :json

    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body).dig("error", "message")).to match(/admin accounts/i)
    expect(admin.reload.paystack_customer_code).to be_nil
  end
end

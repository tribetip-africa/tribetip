# frozen_string_literal: true

require "rails_helper"

RSpec.describe "HttpOnly auth cookies", type: :request do
  def register_and_sign_in(username: "cookie_auth_user")
    post "/tribes.json", params: {
      tribe: {
        email: "#{username}@tribetip.africa",
        password: "securepass123",
        password_confirmation: "securepass123",
        username: username
      }
    }, as: :json

    post "/tribes/sign_in.json", params: {
      tribe: { login: username, password: "securepass123" }
    }, as: :json
    response
  end

  def jwt_cookie
    cookies[Tribetip::Security::AuthCookie::JWT_COOKIE]
  end

  def csrf_cookie
    cookies[Tribetip::Security::AuthCookie::CSRF_COOKIE]
  end

  it "sets HttpOnly JWT and CSRF cookies on sign-in" do
    register_and_sign_in

    expect(response).to have_http_status(:ok)
    expect(jwt_cookie).to be_present
    expect(csrf_cookie).to be_present
    expect(json["csrf_token"]).to eq(csrf_cookie)
  end

  it "authenticates /me/profile via cookie without Authorization header" do
    register_and_sign_in
    tribe = Tribe.find_by!(username: "cookie_auth_user")
    complete_stub_paystack_onboarding!(tribe)

    get "/me/profile", as: :json

    expect(response).to have_http_status(:ok)
    expect(json.dig("profile", "username")).to eq("cookie_auth_user")
  end

  it "rejects mutating cookie-auth requests without a CSRF token" do
    register_and_sign_in

    post "/tribes/session/refresh", as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it "allows mutating cookie-auth requests with a matching CSRF token" do
    register_and_sign_in

    post "/tribes/session/refresh",
      headers: { "X-CSRF-Token" => csrf_cookie },
      as: :json

    expect(response).to have_http_status(:ok)
    expect(json["token"]).to be_present
  end

  it "clears auth cookies on sign-out" do
    register_and_sign_in

    delete "/tribes/sign_out.json",
      headers: { "X-CSRF-Token" => csrf_cookie },
      as: :json

    expect(response).to have_http_status(:ok)
    expect(jwt_cookie).to be_blank
    expect(csrf_cookie).to be_blank
  end
end

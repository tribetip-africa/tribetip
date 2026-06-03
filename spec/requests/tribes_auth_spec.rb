require "rails_helper"

RSpec.describe "Tribes JWT authentication", type: :request do
  def json
    JSON.parse(response.body)
  end

  def auth_header_from(response)
    authorization = response.headers["Authorization"]
    return {} if authorization.blank?

    { "Authorization" => authorization }
  end

  def valid_tribe_params(overrides = {})
    {
      email: "auth-test@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "auth_test_tribe"
    }.merge(overrides)
  end

  def register_tribe(overrides = {})
    post "/tribes.json", params: { tribe: valid_tribe_params(overrides) }, as: :json
  end

  def sign_in_tribe(email: "auth-test@tribetip.africa", password: "securepass123")
    post "/tribes/sign_in.json", params: { tribe: { email: email, password: password } }, as: :json
  end

  describe "POST /tribes" do
    it "creates a tribe and returns created status" do
      register_tribe

      expect(response).to have_http_status(:created)
    end

    it "returns tribe details in the response body" do
      register_tribe

      expect(json["tribe"]).to include("email" => "auth-test@tribetip.africa", "username" => "auth_test_tribe")
    end

    it "returns validation errors for invalid signup data" do
      post "/tribes.json", params: {
        tribe: valid_tribe_params(email: "invalid-email", username: "ab")
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /tribes/sign_in" do
    before { register_tribe }

    it "returns ok for valid credentials" do
      sign_in_tribe

      expect(response).to have_http_status(:ok)
    end

    it "returns tribe details on successful sign in" do
      sign_in_tribe

      expect(json["tribe"]["email"]).to eq("auth-test@tribetip.africa")
    end

    it "returns a bearer token in the Authorization response header" do
      sign_in_tribe

      expect(response.headers["Authorization"]).to start_with("Bearer ")
    end

    it "returns a bearer token in the response body" do
      sign_in_tribe

      expect(json["token"]).to be_present
    end

    it "returns unauthorized for invalid credentials" do
      sign_in_tribe(password: "wrong-password")

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /tribes/sign_out" do
    let(:sign_in_response) do
      register_tribe(username: "signout_tribe")
      sign_in_tribe
      response
    end

    it "signs out successfully when a valid bearer token is provided" do
      delete "/tribes/sign_out.json", headers: auth_header_from(sign_in_response), as: :json

      expect(response).to have_http_status(:ok)
    end

    it "returns unauthorized when no bearer token is provided" do
      delete "/tribes/sign_out.json", as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end

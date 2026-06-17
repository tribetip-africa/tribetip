# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Share profiles", type: :request do
  around do |example|
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache.lookup_store(:memory_store)
    example.run
  ensure
    Rails.cache = original_cache
  end

  def json
    JSON.parse(response.body)
  end

  def create_public_tribe(username: "share_public")
    tribe = Tribe.new(
      email: "#{username}@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: username,
      display_name: "Share Public",
      is_profile_public: true,
      account_status: "active"
    )
    tribe.skip_confirmation!
    tribe.save!
    tribe
  end

  it "returns a public profile for an opaque share token" do
    tribe = create_public_tribe
    token = Tribetip::ShareLinks.ensure_token!(tribe)

    get "/share/#{token}"

    expect(response).to have_http_status(:ok)
    expect(json["profile"]).to include(
      "username" => "share_public",
      "display_name" => "Share Public"
    )
    expect(json["profile"]).not_to include("email")
  end

  it "returns not found for invalid tokens" do
    get "/share/not-a-real-share-token-value"

    expect(response).to have_http_status(:not_found)
  end

  it "returns not found after rotation" do
    tribe = create_public_tribe(username: "share_rotate")
    token = Tribetip::ShareLinks.ensure_token!(tribe)
    Tribetip::ShareLinks.rotate!(tribe)

    get "/share/#{token}"

    expect(response).to have_http_status(:not_found)
    expect(response.headers["Cache-Control"]).to include("no-store")
  end
end

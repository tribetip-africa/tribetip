# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Public profiles", type: :request do
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

  def create_public_tribe(username: "public_creator")
    tribe = Tribe.new(
      email: "#{username}@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: username,
      display_name: "Public Creator",
      is_profile_public: true,
      account_status: "active"
    )
    tribe.skip_confirmation!
    tribe.save!
    tribe
  end

  describe "GET /tribes/:username" do
    it "returns a cacheable public profile without sensitive fields" do
      tribe = create_public_tribe

      get "/tribes/#{tribe.username}"

      expect(response).to have_http_status(:ok)
      expect(response.headers["Cache-Control"]).to include("public")
      expect(json["profile"]).to include(
        "username" => "public_creator",
        "display_name" => "Public Creator"
      )
      expect(json["profile"]).not_to include("email", "encrypted_password")
    end

    it "does not return private profiles" do
      tribe = create_public_tribe(username: "private_creator")
      tribe.update!(is_profile_public: false)

      get "/tribes/#{tribe.username}"

      expect(response).to have_http_status(:not_found)
    end

    it "never caches authenticated reads" do
      create_public_tribe(username: "auth_read")

      get "/tribes/auth_read", headers: { "Authorization" => "Bearer fake.token" }

      expect(response.headers["Cache-Control"]).to include("no-store")
    end

    it "serves updated profile data after cache invalidation" do
      tribe = create_public_tribe(username: "cache_refresh")

      get "/tribes/#{tribe.username}"
      expect(json["profile"]["display_name"]).to eq("Public Creator")

      tribe.update!(display_name: "Updated Creator")

      get "/tribes/#{tribe.username}"
      expect(json["profile"]["display_name"]).to eq("Updated Creator")
    end

    it "stores profile payloads in SecureCache" do
      tribe = create_public_tribe(username: "cache_hit")
      cache_key = Tribetip::SecureCache.public_profile_key(tribe.username)

      get "/tribes/#{tribe.username}"

      cached = Tribetip::SecureCache.read(cache_key, scope: :public)
      expect(cached).to include(display_name: "Public Creator")
    end
  end
end

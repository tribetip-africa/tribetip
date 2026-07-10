# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sitemap creators", type: :request do
  it "returns paginated public creator usernames" do
    create_public_tribe(username: "private_creator", is_profile_public: false)
    create_public_tribe(username: "public_alpha", display_name: "Alpha")
    create_public_tribe(username: "public_beta", display_name: "Beta")

    get "/sitemap/creators", params: { page: 1, per_page: 1 }

    expect(response).to have_http_status(:ok)
    expect(json).to include(
      "page" => 1,
      "per_page" => 1,
      "total_count" => 2,
      "total_pages" => 2
    )
    expect(json.fetch("creators")).to eq(
      [
        {
          "username" => "public_beta",
          "updated_at" => Tribe.find_by!(username: "public_beta").updated_at.iso8601
        }
      ]
    )
  end

  it "excludes suspended and admin profiles" do
    create_public_tribe(username: "active_creator")
    suspended = create_public_tribe(username: "suspended_creator")
    suspended.update!(account_status: "suspended")

    admin = create_public_tribe(username: "admin_creator")
    admin.update!(role: "admin", is_profile_public: false)

    get "/sitemap/creators"

    usernames = json.fetch("creators").pluck("username")
    expect(usernames).to eq(["active_creator"])
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Creator share links", type: :request do
  it "returns an opaque share link for the signed-in creator" do
    tribe = create_creator

    get "/me/share_link", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:ok)
    link = json.fetch("share_link")
    expect(link.fetch("token")).to be_present
    expect(link.fetch("path")).to start_with("/t/")
    expect(link.fetch("url")).to include("/t/")
    expect(link.fetch("url")).not_to include(tribe.username)
    expect(link.fetch("shareable")).to be(true)
  end

  it "rotates the share token" do
    tribe = create_creator(username: "share_rotate_me")
    get "/me/share_link", headers: bearer_token_for(tribe), as: :json
    original = json.dig("share_link", "token")

    post "/me/share_link/rotate", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:ok)
    rotated = json.dig("share_link", "token")
    expect(rotated).not_to eq(original)
    expect(tribe.reload.tip_share_token).to eq(rotated)
  end
end

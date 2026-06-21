# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Creator widget embeds", type: :request do
  it "returns widget embed settings for the signed-in creator" do
    tribe = create_creator

    get "/me/widget_embed", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:ok)
    embed = json.fetch("widget_embed")
    expect(embed.fetch("enabled")).to be(false)
    expect(embed.fetch("token")).to be_nil
    expect(embed.fetch("embed_snippet")).to be_nil
  end

  it "enables the widget and returns an embed snippet" do
    tribe = create_creator(username: "widget_enable")

    patch "/me/widget_embed",
          params: { widget_embed: { widget_enabled: true, widget_cta_text: "Support me" } },
          headers: bearer_token_for(tribe),
          as: :json

    expect(response).to have_http_status(:ok)
    embed = json.fetch("widget_embed")
    expect(embed.fetch("enabled")).to be(true)
    expect(embed.fetch("token")).to be_present
    expect(embed.fetch("embed_snippet")).to include("widget.js?token=")
    expect(embed.fetch("cta_text")).to eq("Support me")
    expect(tribe.reload.widget_enabled?).to be(true)
  end

  it "rotates the widget token" do
    tribe = create_creator(username: "widget_rotate")
    patch "/me/widget_embed",
          params: { widget_embed: { widget_enabled: true } },
          headers: bearer_token_for(tribe),
          as: :json
    original = json.dig("widget_embed", "token")

    post "/me/widget_embed/rotate", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:ok)
    rotated = json.dig("widget_embed", "token")
    expect(rotated).not_to eq(original)
    expect(tribe.reload.widget_embed_token).to eq(rotated)
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Public widget config", type: :request do
  it "returns widget configuration for a valid enabled token" do
    tribe = create_creator(
      username: "widget_public",
      display_name: "Widget Public",
      widget_enabled: true
    )
    token = Tribetip::WidgetEmbed.ensure_token!(tribe)

    get "/widget/config?token=#{CGI.escape(token)}", headers: { Accept: "application/json" }

    expect(response).to have_http_status(:ok)
    config = json.fetch("config")
    expect(config.fetch("app_name")).to eq("Widget Public")
    expect(config.fetch("username")).to eq("widget_public")
    expect(config.fetch("destination_url")).to include("/t/")
    expect(config.fetch("cta_text")).to eq("Support @widget_public")
    expect(config.fetch("position")).to eq("bottom-right")
    expect(config.fetch("tip_presets")).to eq([ "KSh 500", "KSh 1,000", "Custom" ])
    expect(config.fetch("payment_hint")).to include("M-Pesa")
  end

  it "returns not found for invalid tokens" do
    get "/widget/config?token=not-a-real-token", headers: { Accept: "application/json" }

    expect(response).to have_http_status(:not_found)
  end

  it "returns not found when the widget is disabled" do
    tribe = create_creator(username: "widget_off")
    token = Tribetip::WidgetEmbed.ensure_token!(tribe)
    tribe.update!(widget_enabled: false)

    get "/widget/config?token=#{CGI.escape(token)}", headers: { Accept: "application/json" }

    expect(response).to have_http_status(:not_found)
  end
end

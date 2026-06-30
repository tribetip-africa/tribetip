# frozen_string_literal: true

require "rails_helper"

# Locks the security invariant that the opaque widget / QR / share tokens can
# never be used as an authentication credential, and that a login JWT can never
# be used as a widget/share token. The two token systems must stay disjoint so a
# leaked embed/QR token can never be replayed to gain a logged-in session.
RSpec.describe "Token system separation", type: :request do
  def jwt_for(tribe)
    bearer_token_for(tribe).fetch("Authorization").delete_prefix("Bearer ")
  end

  it "rejects a widget embed token presented as a bearer auth credential" do
    tribe = create_creator(username: "tokensep_widget", widget_enabled: true)
    widget_token = Tribetip::WidgetEmbed.ensure_token!(tribe)

    get "/me/widget_embed",
        headers: { "Authorization" => "Bearer #{widget_token}" },
        as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects a share link token presented as a bearer auth credential" do
    tribe = create_creator(username: "tokensep_share")
    share_token = Tribetip::ShareLinks.ensure_token!(tribe)

    get "/me/share_link",
        headers: { "Authorization" => "Bearer #{share_token}" },
        as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects a login JWT presented as a widget config token" do
    tribe = create_creator(username: "tokensep_jwt", widget_enabled: true)
    Tribetip::WidgetEmbed.ensure_token!(tribe)

    get "/widget/config?token=#{CGI.escape(jwt_for(tribe))}",
        headers: { Accept: "application/json" }

    expect(response).to have_http_status(:not_found)
  end

  it "keeps opaque tokens in a format disjoint from JWTs" do
    tribe = create_creator(username: "tokensep_fmt", widget_enabled: true)
    widget_token = Tribetip::WidgetEmbed.ensure_token!(tribe)
    share_token = Tribetip::ShareLinks.ensure_token!(tribe)
    jwt = jwt_for(tribe)

    opaque_pattern = /\A[A-Za-z0-9_-]{20,48}\z/
    expect(widget_token).to match(opaque_pattern)
    expect(share_token).to match(opaque_pattern)
    expect(widget_token).not_to eq(share_token)

    # A JWT is dotted and longer than 48 chars, so it can never satisfy the
    # opaque-token format check the widget/share resolvers enforce.
    expect(jwt).to include(".")
    expect(jwt).not_to match(opaque_pattern)
    expect(Tribetip::WidgetEmbed.valid_token_format?(jwt)).to be(false)
    expect(Tribetip::ShareLinks.valid_token_format?(jwt)).to be(false)
  end
end

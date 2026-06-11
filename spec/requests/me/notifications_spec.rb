# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Creator notifications", type: :request do
  def json
    JSON.parse(response.body)
  end

  def create_creator(username:)
    tribe = Tribe.create!(
      email: "#{username}@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: username,
      country_code: "KE",
      currency: "KES"
    )
    complete_stub_paystack_onboarding!(tribe)
    tribe.reload
  end

  def bearer_token_for(tribe)
    token, = Warden::JWTAuth::UserEncoder.new.call(tribe, :tribe, nil)
    { "Authorization" => "Bearer #{token}" }
  end

  it "lists unread notifications for creators" do
    tribe = create_creator(username: "notifications_creator")
    tribe.creator_notifications.create!(
      kind: "settlement_paid",
      title: "Settlement sent",
      body: "KES 950.00 was sent to M-PESA.",
      metadata: { paystack_transfer_code: "TRF_notify_list" }
    )

    get "/me/notifications", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:ok)
    expect(json.fetch("notifications").length).to eq(1)
    expect(json["unread_count"]).to eq(1)
  end

  it "marks notifications as read" do
    tribe = create_creator(username: "notifications_read")
    notification = tribe.creator_notifications.create!(
      kind: "settlement_paid",
      title: "Settlement sent",
      body: "KES 950.00 was sent to M-PESA.",
      metadata: { paystack_transfer_code: "TRF_notify_read" }
    )

    patch "/me/notifications/#{notification.id}/read", headers: bearer_token_for(tribe), as: :json

    expect(response).to have_http_status(:ok)
    expect(notification.reload.read_at).to be_present
  end
end

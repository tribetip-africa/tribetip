# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin Paystack events", type: :request do
  def json
    JSON.parse(response.body)
  end

  def create_admin
    Tribe.create!(
      email: "admin_events@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "admin_events",
      role: "admin"
    )
  end

  def auth_headers(tribe)
    post "/tribes/sign_in",
         params: { tribe: { login: tribe.email, password: "securepass123" } },
         as: :json
    token = response.headers["Authorization"]&.delete_prefix("Bearer ")
    { "Authorization" => "Bearer #{token}" }
  end

  it "lists webhook events for admins" do
    admin = create_admin
    PaystackEvent.create!(
      event_id: "paystack:charge.success:tip_admin_list",
      event_type: "charge.success",
      status: "failed",
      payload: { "event" => "charge.success", "data" => { "reference" => "tip_admin_list" } },
      error_message: "temporary failure"
    )

    get "/admin/paystack_events", headers: auth_headers(admin), as: :json

    expect(response).to have_http_status(:ok)
    expect(json.fetch("events").first.fetch("paystack_reference")).to eq("tip_admin_list")
  end

  it "replays failed webhook events" do
    admin = create_admin
    event = PaystackEvent.create!(
      event_id: "paystack:charge.success:tip_admin_replay",
      event_type: "charge.success",
      status: "failed",
      payload: { "event" => "charge.success", "data" => { "reference" => "tip_admin_replay" } },
      error_message: "temporary failure"
    )

    allow(Paystack::ProcessWebhookJob).to receive(:perform_later)

    post "/admin/paystack_events/#{event.id}/replay", headers: auth_headers(admin), as: :json

    expect(Paystack::ProcessWebhookJob).to have_received(:perform_later).with(event.id)
    expect(response).to have_http_status(:ok)
    expect(event.reload.status).to eq("pending")
    expect(event.error_message).to be_nil
    expect(json.dig("event", "status")).to eq("pending")
  end
end

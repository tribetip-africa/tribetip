# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin Paystack audits", type: :request do

  def token_for(username)
    post "/tribes/sign_in.json", params: {
      tribe: { login: username, password: "securepass123" }
    }, as: :json

    response.headers["Authorization"]&.delete_prefix("Bearer ") || json["token"]
  end

  let(:target) do
    tribe = create_tribe(username: "audit_target")
    complete_stub_paystack_onboarding!(tribe)
    tribe
  end
  let(:admin) { create_tribe(username: "audit_admin", role: "admin") }
  let(:creator) { create_tribe(username: "audit_creator") }

  before do
    target
    admin
    creator
  end

  it "allows admins to audit Paystack onboarding for a tribe" do
    get "/admin/tribes/#{target.id}/paystack_audit",
        headers: { "Authorization" => "Bearer #{token_for('audit_admin')}" },
        as: :json

    expect(response).to have_http_status(:ok)
    expect(json.dig("audit", "username")).to eq("audit_target")
    expect(json.dig("audit", "healthy")).to be(true)
    expect(json.dig("audit", "checks")).to be_present
  end

  it "forbids creators from auditing Paystack onboarding" do
    get "/admin/tribes/#{target.id}/paystack_audit",
        headers: { "Authorization" => "Bearer #{token_for('audit_creator')}" },
        as: :json

    expect(response).to have_http_status(:forbidden)
    expect(json.dig("error", "code")).to eq("forbidden")
  end

  it "reconciles onboarding state when sync=true" do
    target.update_columns(onboarding_completed_at: nil)

    get "/admin/tribes/#{target.id}/paystack_audit?sync=true",
        headers: { "Authorization" => "Bearer #{token_for('audit_admin')}" },
        as: :json

    expect(response).to have_http_status(:ok)
    expect(json.dig("audit", "onboarding_complete")).to be(true)
    expect(target.reload.onboarding_completed_at).to be_present
  end
end

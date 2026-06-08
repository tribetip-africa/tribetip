# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminAuditLog do
  it "records admin actions" do
    admin = Tribe.create!(
      email: "admin_log@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "admin_log",
      role: "admin"
    )
    target = Tribe.create!(
      email: "target_log@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "target_log"
    )

    log = Tribetip::Audit::RecordAdminAction.call(
      admin: admin,
      action: "suspend_tribe",
      target: target,
      details: { reason: "test" }
    )

    expect(log).to be_persisted
    expect(log.action).to eq("suspend_tribe")
  end
end

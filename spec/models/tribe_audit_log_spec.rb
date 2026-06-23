# frozen_string_literal: true

require "rails_helper"

RSpec.describe TribeAuditLog do
  it "records creator security actions" do
    tribe = create_onboarded_tribe(username: "tribe_audit_log")

    log = Tribetip::Audit::RecordTribeAction.call(
      tribe: tribe,
      action: "account_number_revealed",
      details: { market: "KE", subaccount_code_suffix: "seed" }
    )

    expect(log).to be_persisted
    expect(log.action).to eq("account_number_revealed")
    expect(log.details).to include("market" => "KE")
  end
end

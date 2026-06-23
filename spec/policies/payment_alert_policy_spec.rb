# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentAlertPolicy do
  let(:alert) do
    PaymentAlert.create!(
      kind: "settlement_tribe_rejected",
      title: "Policy spec alert",
      body: "Test alert.",
      metadata: { transfer_code: "TRF_policy_spec" }
    )
  end

  describe "#index?" do
    it "allows admins" do
      admin = create_tribe(username: "payment_alert_admin", role: "admin", account_status: "active")
      context = Tribetip::Authorization::Context.new(subject: admin)

      expect(described_class.new(context, PaymentAlert).index?).to be(true)
    end

    it "denies creators" do
      creator = create_tribe(username: "payment_alert_creator", account_status: "active")
      context = Tribetip::Authorization::Context.new(subject: creator)

      expect(described_class.new(context, PaymentAlert).index?).to be(false)
    end
  end

  describe "Scope" do
    before { alert }

    it "returns alerts for admins" do
      admin = create_tribe(username: "payment_alert_scope_admin", role: "admin", account_status: "active")
      context = Tribetip::Authorization::Context.new(subject: admin)

      expect(described_class::Scope.new(context, PaymentAlert).resolve).to include(alert)
    end

    it "returns no alerts for creators" do
      creator = create_tribe(username: "payment_alert_scope_creator", account_status: "active")
      context = Tribetip::Authorization::Context.new(subject: creator)

      expect(described_class::Scope.new(context, PaymentAlert).resolve).to be_empty
    end
  end
end

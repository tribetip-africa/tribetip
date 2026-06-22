# frozen_string_literal: true

require "rails_helper"

RSpec.describe TribePolicy do
  subject(:policy) { described_class.new(context, tribe) }

  let(:tribe) { create_tribe(username: "policy_creator", account_status: "active") }
  let(:context) { Tribetip::Authorization::Context.new(subject: tribe, resource: tribe) }

  describe "#access_dashboard?" do
    it "allows creators with linked payout accounts" do
      complete_stub_paystack_onboarding!(tribe)

      expect(policy.access_dashboard?).to be(true)
    end

    it "denies creators without payout setup" do
      expect(policy.access_dashboard?).to be(false)
    end
  end

  describe "#manage_widget?" do
    it "allows creators" do
      expect(policy.manage_widget?).to be(true)
    end

    it "denies admins" do
      admin = create_tribe(username: "policy_admin", role: "admin", account_status: "active")

      expect(described_class.new(Tribetip::Authorization::Context.new(subject: admin, resource: admin), admin).manage_widget?).to be(false)
    end
  end

  describe "#publish?" do
    it "requires payout readiness and display name" do
      complete_stub_paystack_onboarding!(tribe)
      tribe.update!(display_name: "Policy Creator")

      expect(policy.publish?).to be(true)
    end
  end
end

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

  describe "#index?" do
    it "allows admins" do
      admin = create_tribe(username: "policy_admin_index", role: "admin", account_status: "active")
      admin_context = Tribetip::Authorization::Context.new(subject: admin)

      expect(described_class.new(admin_context, Tribe).index?).to be(true)
    end

    it "denies creators" do
      expect(described_class.new(context, Tribe).index?).to be(false)
    end
  end

  describe "Scope" do
    it "returns all tribes for admins" do
      admin = create_tribe(username: "policy_admin_scope", role: "admin", account_status: "active")
      admin_context = Tribetip::Authorization::Context.new(subject: admin)

      expect(described_class::Scope.new(admin_context, Tribe).resolve.count).to be >= 1
    end

    it "returns no tribes for creators" do
      expect(described_class::Scope.new(context, Tribe).resolve).to be_empty
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

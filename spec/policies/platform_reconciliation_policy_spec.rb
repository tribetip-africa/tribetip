# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlatformReconciliationPolicy do
  let(:admin) { create_tribe(username: "platform_reconcile_admin", role: "admin", account_status: "active") }
  let(:creator) { create_tribe(username: "platform_reconcile_creator", account_status: "active") }
  let(:admin_context) { Tribetip::Authorization::Context.new(subject: admin) }
  let(:creator_context) { Tribetip::Authorization::Context.new(subject: creator) }

  describe "#show?" do
    it "allows admins" do
      expect(described_class.new(admin_context, PlatformReconciliation).show?).to be(true)
    end

    it "denies creators" do
      expect(described_class.new(creator_context, PlatformReconciliation).show?).to be(false)
    end
  end

  describe "#create?" do
    it "allows admins" do
      expect(described_class.new(admin_context, PlatformReconciliation).create?).to be(true)
    end

    it "denies creators" do
      expect(described_class.new(creator_context, PlatformReconciliation).create?).to be(false)
    end
  end
end

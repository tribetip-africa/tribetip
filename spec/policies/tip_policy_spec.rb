# frozen_string_literal: true

require "rails_helper"

RSpec.describe TipPolicy do
  subject(:policy) { described_class.new(context, tip) }

  let(:tribe) { create_tribe(username: "tip_policy_owner", account_status: "active") }
  let(:tip) do
    tribe.tips.create!(
      amount_cents: 50_000,
      currency: "KES",
      status: "pending",
      paystack_reference: "tip_policy_ref",
      supporter_email: "fan@example.com"
    )
  end
  let(:context) { Tribetip::Authorization::Context.new(subject: tribe, resource: tip) }

  describe "#show?" do
    it "allows the tip owner" do
      expect(policy.show?).to be(true)
    end

    it "denies other creators" do
      other = create_tribe(username: "tip_policy_other", account_status: "active")
      other_context = Tribetip::Authorization::Context.new(subject: other, resource: tip)

      expect(described_class.new(other_context, tip).show?).to be(false)
    end
  end

  describe "#reconcile?" do
    it "allows owners to reconcile pending tips" do
      expect(policy.reconcile?).to be(true)
    end

    it "denies reconcile on paid tips" do
      tip.update!(status: "paid", paid_at: Time.current)

      expect(policy.reconcile?).to be(false)
    end
  end

  describe "#investigate?" do
    it "allows admins" do
      admin = create_tribe(username: "tip_policy_admin", role: "admin", account_status: "active")
      admin_context = Tribetip::Authorization::Context.new(subject: admin, resource: tip)

      expect(described_class.new(admin_context, tip).investigate?).to be(true)
    end

    it "denies creators" do
      expect(policy.investigate?).to be(false)
    end
  end
end

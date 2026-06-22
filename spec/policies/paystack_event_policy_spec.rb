# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaystackEventPolicy do
  let(:event) do
    PaystackEvent.create!(
      event_id: "paystack:charge.success:policy_spec",
      event_type: "charge.success",
      status: "failed",
      payload: { "event" => "charge.success", "data" => { "reference" => "policy_spec" } }
    )
  end

  describe "#index?" do
    it "allows admins" do
      admin = create_tribe(username: "paystack_event_admin", role: "admin", account_status: "active")
      context = Tribetip::Authorization::Context.new(subject: admin)

      expect(described_class.new(context, PaystackEvent).index?).to be(true)
    end

    it "denies creators" do
      creator = create_tribe(username: "paystack_event_creator", account_status: "active")
      context = Tribetip::Authorization::Context.new(subject: creator)

      expect(described_class.new(context, PaystackEvent).index?).to be(false)
    end
  end

  describe "#replay?" do
    it "allows admins" do
      admin = create_tribe(username: "paystack_event_replay_admin", role: "admin", account_status: "active")
      context = Tribetip::Authorization::Context.new(subject: admin, resource: event)

      expect(described_class.new(context, event).replay?).to be(true)
    end

    it "denies creators" do
      creator = create_tribe(username: "paystack_event_replay_creator", account_status: "active")
      context = Tribetip::Authorization::Context.new(subject: creator, resource: event)

      expect(described_class.new(context, event).replay?).to be(false)
    end
  end

  describe "Scope" do
    before { event }

    it "returns events for admins" do
      admin = create_tribe(username: "paystack_event_scope_admin", role: "admin", account_status: "active")
      context = Tribetip::Authorization::Context.new(subject: admin)

      expect(described_class::Scope.new(context, PaystackEvent).resolve).to include(event)
    end

    it "returns no events for creators" do
      creator = create_tribe(username: "paystack_event_scope_creator", account_status: "active")
      context = Tribetip::Authorization::Context.new(subject: creator)

      expect(described_class::Scope.new(context, PaystackEvent).resolve).to be_empty
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Audit::RecordTipEvent do
  def create_tip(reference: "tip_audit_event")
    tribe = Tribe.create!(
      email: "audit@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "audit_creator"
    )
    complete_stub_paystack_onboarding!(tribe)

    tribe.tips.create!(
      amount_cents: 50_000,
      currency: "NGN",
      paystack_reference: reference,
      supporter_email: "fan@tribetip.africa",
      status: "pending"
    )
  end

  it "records a tip lifecycle event" do
    tip = create_tip

    event = described_class.call(
      tip: tip,
      action: "created",
      from_status: nil,
      to_status: "pending",
      source: "public"
    )

    expect(event).to be_persisted
    expect(event.action).to eq("created")
    expect(TipEvent.count).to eq(1)
  end
end

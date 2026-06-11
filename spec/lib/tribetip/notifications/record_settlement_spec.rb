# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Notifications::RecordSettlement do
  def create_settlement(status:)
    tribe = Tribe.create!(
      email: "notify_inapp@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "notify_inapp",
      country_code: "KE",
      currency: "KES"
    )
    complete_stub_paystack_onboarding!(tribe)

    tribe.paystack_settlements.create!(
      paystack_transfer_code: "TRF_inapp_#{status}",
      amount_cents: 95_000,
      currency: "KES",
      status: status,
      settled_at: Time.current,
      destination: "M-PESA · ••5678"
    )
  end

  it "creates an in-app notification for successful settlements" do
    settlement = create_settlement(status: "success")

    expect do
      described_class.call(settlement, event_type: "transfer.success")
    end.to change { CreatorNotification.count }.by(1)

    notification = CreatorNotification.last
    expect(notification.kind).to eq("settlement_paid")
    expect(notification.metadata["paystack_transfer_code"]).to eq("TRF_inapp_success")
  end

  it "does not duplicate notifications for the same settlement" do
    settlement = create_settlement(status: "success")

    described_class.call(settlement, event_type: "transfer.success")

    expect do
      described_class.call(settlement, event_type: "transfer.success")
    end.not_to change { CreatorNotification.count }
  end
end

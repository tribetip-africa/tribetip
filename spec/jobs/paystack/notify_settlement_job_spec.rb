# frozen_string_literal: true

require "rails_helper"

RSpec.describe Paystack::NotifySettlementJob, type: :job do
  def create_settlement(status:)
    tribe = Tribe.create!(
      email: "notify@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: "notify_settlement",
      country_code: "KE",
      currency: "KES"
    )
    complete_stub_paystack_onboarding!(tribe)

    tribe.paystack_settlements.create!(
      paystack_transfer_code: "TRF_notify_#{status}",
      amount_cents: 50_000,
      currency: "KES",
      status: status,
      settled_at: Time.current,
      destination: "M-PESA · ••5678"
    )
  end

  it "creates an in-app notification for successful settlements" do
    settlement = create_settlement(status: "success")

    expect do
      described_class.perform_now(settlement.id, "transfer.success")
    end.to change(CreatorNotification, :count).by(1)
  end

  it "sends a paid settlement email" do
    settlement = create_settlement(status: "success")

    expect do
      described_class.perform_now(settlement.id, "transfer.success")
    end.to change { ActionMailer::Base.deliveries.size }.by(1)

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([ settlement.tribe.email ])
    expect(mail.subject).to include("Settlement sent")
  end

  it "sends a failed settlement email" do
    settlement = create_settlement(status: "failed")

    expect do
      described_class.perform_now(settlement.id, "transfer.failed")
    end.to change { ActionMailer::Base.deliveries.size }.by(1)

    mail = ActionMailer::Base.deliveries.last
    expect(mail.subject).to include("Settlement issue")
  end
end

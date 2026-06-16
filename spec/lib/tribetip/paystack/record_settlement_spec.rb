# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Paystack::RecordSettlement do
  def create_tribe(username: "record_settlement")
    tribe = Tribe.create!(
      email: "#{username}@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: username,
      country_code: "KE",
      currency: "KES"
    )
    complete_stub_paystack_onboarding!(tribe)
    tribe.reload
  end

  it "records a settlement from a transfer webhook payload" do
    tribe = create_tribe

    result = described_class.call(
      payload: {
        transfer_code: "TRF_test_123",
        amount: 95_000,
        currency: "KES",
        status: "success",
        reference: "settlement_ref",
        createdAt: "2026-06-04T12:00:00Z",
        metadata: {
          tribe_id: tribe.id,
          subaccount_code: tribe.paystack_subaccount_code
        },
        recipient: {
          details: {
            account_number: "0712345678",
            bank_name: "M-PESA"
          }
        }
      },
      event_type: "transfer.success"
    )

    settlement = result.settlement
    expect(settlement).to be_present
    expect(settlement.tribe_id).to eq(tribe.id)
    expect(settlement.status).to eq("success")
    expect(settlement.amount_cents).to eq(95_000)
    expect(settlement.metadata["source"]).to eq("webhook")
  end

  it "enqueues settlement notifications for webhook events" do
    tribe = create_tribe(username: "notify_record")

    expect(::Paystack::NotifySettlementJob).to receive(:perform_later).with(kind_of(String), "transfer.success")

    described_class.call(
      payload: {
        transfer_code: "TRF_notify_enqueue",
        amount: 50_000,
        currency: "KES",
        status: "success",
        metadata: { tribe_id: tribe.id }
      },
      event_type: "transfer.success"
    )
  end

  it "links a settlement to a tip via paystack reference" do
    tribe = create_tribe(username: "linked_settlement")
    tip = tribe.tips.create!(
      amount_cents: 50_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_linked_settlement",
      supporter_email: "fan@example.com",
      paid_at: 1.day.ago
    )

    result = described_class.call(
      payload: {
        transfer_code: "TRF_linked_tip",
        amount: 47_500,
        currency: "KES",
        status: "success",
        reference: tip.paystack_reference,
        metadata: { tribe_id: tribe.id }
      },
      event_type: "transfer.success"
    )

    expect(result.settlement.tip_id).to eq(tip.id)
  end

  it "links a settlement to a tip via metadata tip_id" do
    tribe = create_tribe(username: "metadata_tip_link")
    tip = tribe.tips.create!(
      amount_cents: 50_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_metadata_link",
      supporter_email: "fan@example.com",
      paid_at: 1.day.ago
    )

    result = described_class.call(
      payload: {
        transfer_code: "TRF_metadata_tip",
        amount: 47_500,
        currency: "KES",
        status: "success",
        reference: "wd_sim_unrelated",
        metadata: { tribe_id: tribe.id, tip_id: tip.id }
      },
      event_type: "transfer.success"
    )

    expect(result.settlement.tip_id).to eq(tip.id)
  end

  it "upserts settlement rows from sync records" do
    tribe = create_tribe(username: "sync_settlement")
    record = Tribetip::Paystack::SettlementRecord.new(
      id: "settlement_sync_ref",
      amount_cents: 47_500,
      currency: "KES",
      status: "success",
      settled_at: 1.day.ago,
      destination: "M-PESA · ••5678",
      reference: "tip_sync_ref"
    )

    described_class.call(tribe: tribe, record: record)
    described_class.call(tribe: tribe, record: record)

    expect(PaystackSettlement.where(tribe: tribe).count).to eq(1)
    expect(PaystackSettlement.find_by!(paystack_transfer_code: "settlement_sync_ref").metadata["source"]).to eq("sync")
  end
end

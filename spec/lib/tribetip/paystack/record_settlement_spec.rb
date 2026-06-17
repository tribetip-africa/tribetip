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

    allow(::Paystack::NotifySettlementJob).to receive(:perform_later)

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

    expect(::Paystack::NotifySettlementJob).to have_received(:perform_later)
      .with(kind_of(String), "transfer.success")
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

  it "skips settlement recording when tribe metadata conflicts" do
    tribe_a = create_tribe(username: "settlement_a")
    tribe_b = create_tribe(username: "settlement_b")

    result = described_class.call(
      payload: {
        transfer_code: "TRF_conflict",
        amount: 47_500,
        currency: "KES",
        status: "success",
        metadata: {
          tribe_id: tribe_a.id,
          subaccount_code: tribe_b.paystack_subaccount_code
        }
      },
      event_type: "transfer.success"
    )

    expect(result.skipped).to be(true)
    expect(PaystackSettlement.find_by(paystack_transfer_code: "TRF_conflict")).to be_nil
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

  it "reuses an existing tip settlement instead of creating a duplicate transfer code" do
    tribe = create_tribe(username: "dedupe_settlement")
    tip = tribe.tips.create!(
      amount_cents: 50_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_dedupe_settlement",
      supporter_email: "fan@example.com",
      paid_at: 1.day.ago
    )
    tribe.paystack_settlements.create!(
      paystack_transfer_code: "TRF_sim_old",
      amount_cents: 47_500,
      currency: "KES",
      status: "success",
      settled_at: 1.day.ago,
      destination: "M-PESA",
      reference: tip.paystack_reference,
      tip: tip
    )

    result = described_class.call(
      payload: {
        transfer_code: "settlement_tip_dedupe_settlement",
        amount: 47_500,
        currency: "KES",
        status: "success",
        reference: tip.paystack_reference,
        metadata: { tribe_id: tribe.id, tip_id: tip.id, source: "simulate-settlement" }
      },
      event_type: "transfer.success"
    )

    expect(PaystackSettlement.where(tribe: tribe, tip_id: tip.id).count).to eq(1)
    expect(result.settlement.paystack_transfer_code).to eq("settlement_tip_dedupe_settlement")
  end

  it "upgrades a stub settlement to a Paystack transfer code when syncing remote data" do
    tribe = create_tribe(username: "upgrade_settlement")
    tip = tribe.tips.create!(
      amount_cents: 50_000,
      currency: "KES",
      status: "paid",
      paystack_reference: "tip_upgrade_settlement",
      supporter_email: "fan@example.com",
      paid_at: 1.day.ago
    )
    tribe.paystack_settlements.create!(
      paystack_transfer_code: Tribetip::Paystack::SettlementRecord.transfer_code_for_tip(tip),
      amount_cents: 47_500,
      currency: "KES",
      status: "success",
      settled_at: 1.day.ago,
      destination: "M-PESA",
      reference: tip.paystack_reference,
      tip: tip,
      metadata: { "source" => "simulate-settlement" }
    )

    described_class.call(
      tribe: tribe,
      record: Tribetip::Paystack::SettlementRecord.new(
        id: "TRF_live_upgrade",
        amount_cents: 47_500,
        currency: "KES",
        status: "success",
        settled_at: Time.current,
        destination: "M-PESA",
        reference: tip.paystack_reference
      )
    )

    settlement = tribe.paystack_settlements.find_by!(tip_id: tip.id)
    expect(settlement.paystack_transfer_code).to eq("TRF_live_upgrade")
    expect(PaystackSettlement.where(tribe: tribe).count).to eq(1)
  end
end

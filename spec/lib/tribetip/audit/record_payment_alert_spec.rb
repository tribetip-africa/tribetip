# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Audit::RecordPaymentAlert do
  it "creates a payment alert" do
    alert = described_class.call(
      kind: "settlement_tribe_rejected",
      title: "Settlement webhook rejected",
      body: "Rejected TRF_test: tribe id subaccount conflict.",
      metadata: { transfer_code: "TRF_test", reason: "tribe_id_subaccount_conflict" }
    )

    expect(alert).to be_a(PaymentAlert)
    expect(alert.kind).to eq("settlement_tribe_rejected")
    expect(alert.metadata["transfer_code"]).to eq("TRF_test")
  end

  it "deduplicates unresolved alerts for the same transfer code" do
    metadata = { transfer_code: "TRF_dup", reason: "tribe_id_subaccount_conflict" }

    described_class.call(
      kind: "settlement_tribe_rejected",
      title: "Settlement webhook rejected",
      body: "Rejected TRF_dup.",
      metadata: metadata
    )

    expect do
      described_class.call(
        kind: "settlement_tribe_rejected",
        title: "Settlement webhook rejected",
        body: "Rejected TRF_dup again.",
        metadata: metadata
      )
    end.not_to change(PaymentAlert, :count)
  end

  it "deduplicates unresolved alerts for the same audit key" do
    metadata = { audit_key: "platform:stale_pending_tips", count: 2 }

    described_class.call(
      kind: "stale_pending_tips",
      title: "Stale pending tips detected",
      body: "2 tip(s) remain pending.",
      metadata: metadata
    )

    expect do
      described_class.call(
        kind: "stale_pending_tips",
        title: "Stale pending tips detected",
        body: "Still pending.",
        metadata: metadata.merge(count: 3)
      )
    end.not_to change(PaymentAlert, :count)
  end
end

# frozen_string_literal: true

# Emits a JSON snapshot of platform counts for load/E2E consistency checks.
# Usage: bin/rails runner scripts/loadtest/snapshot-consistency.rb

duplicate_refs = Tip.group(:paystack_reference).having("COUNT(*) > 1").count.keys

snapshot = {
  captured_at: Time.current.iso8601,
  tribes: Tribe.count,
  tips: {
    total: Tip.count,
    pending: Tip.where(status: "pending").count,
    paid: Tip.paid.count,
    failed: Tip.where(status: "failed").count,
    loadtest: Tip.where("supporter_email LIKE ?", "loadtest+%@tribetip.africa").count,
    loadtest_pending: Tip.where("supporter_email LIKE ?", "loadtest+%@tribetip.africa")
      .where(status: "pending").count
  },
  duplicate_paystack_references: duplicate_refs,
  paystack_events: {
    total: PaystackEvent.count,
    retryable_failed: PaystackEvent.retryable.count
  },
  idempotency_keys: IdempotencyKey.count,
  payment_alerts_unresolved: PaymentAlert.unresolved.count
}

puts JSON.pretty_generate(snapshot)

# frozen_string_literal: true

# Validates data invariants after a load + E2E run.
# Usage: bin/rails runner scripts/loadtest/verify-consistency.rb BEFORE.json AFTER.json

before_path = ARGV[0] || ENV.fetch("LOADTEST_BEFORE_SNAPSHOT", nil)
after_path = ARGV[1] || ENV.fetch("LOADTEST_AFTER_SNAPSHOT", nil)

raise "Missing before snapshot path" if before_path.blank?
raise "Missing after snapshot path" if after_path.blank?

before = JSON.parse(File.read(before_path))
after = JSON.parse(File.read(after_path))

errors = []
warnings = []

if after.fetch("duplicate_paystack_references", []).any?
  errors << "Duplicate paystack_reference values detected: #{after['duplicate_paystack_references'].join(', ')}"
end

loadtest_delta = after.dig("tips", "loadtest").to_i - before.dig("tips", "loadtest").to_i
if loadtest_delta.negative?
  errors << "Load-test tip count decreased (#{loadtest_delta})"
end

if after.dig("tips", "total").to_i < before.dig("tips", "total").to_i
  errors << "Total tip count decreased during the run"
end

if after.dig("paystack_events", "retryable_failed").to_i > before.dig("paystack_events", "retryable_failed").to_i + 5
  warnings << "Retryable failed webhook backlog grew significantly"
end

invalid_tips = Tip.where.not(status: Tip::VALID_STATUSES).count
errors << "#{invalid_tips} tip(s) have invalid status values" if invalid_tips.positive?

orphan_events = PaystackEvent.where.not(tip_id: nil).where.missing(:tip).count
errors << "#{orphan_events} PaystackEvent row(s) reference missing tips" if orphan_events.positive?

report = Tribetip::Paystack::ReconcilePlatform.call(auto_repair: false)
critical = report.findings.select { |finding| finding.severity == "critical" }

unless ENV["LOADTEST_STRICT_RECONCILE"] == "true"
  critical = critical.reject { |finding| finding.kind == "tip_payment_mismatch" }
end

if critical.any?
  critical.each do |finding|
    errors << "ReconcilePlatform critical: #{finding.kind} — #{finding.title}"
  end
end

warnings.concat(
  report.findings
    .select { |finding| finding.severity == "warning" }
    .reject { |finding| finding.kind == "stale_pending_tips" && loadtest_delta.positive? }
    .map { |finding| "#{finding.kind}: #{finding.title}" }
)

result = {
  checked_at: Time.current.iso8601,
  before_captured_at: before["captured_at"],
  after_captured_at: after["captured_at"],
  loadtest_tips_created: loadtest_delta,
  reconcile_findings: report.summary,
  errors: errors,
  warnings: warnings,
  passed: errors.empty?
}

puts JSON.pretty_generate(result)

if errors.any?
  warn "\nConsistency verification FAILED:"
  errors.each { |message| warn "  - #{message}" }
  exit 1
end

warn "\nConsistency verification passed."
warnings.each { |message| warn "  warning: #{message}" } if warnings.any?

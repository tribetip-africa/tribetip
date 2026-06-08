#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"

def git(*args)
  out, err, status = Open3.capture3("git", *args)
  raise "git #{args.join(' ')} failed: #{err}" unless status.success?

  out
end

def porcelain_files
  git("status", "--porcelain", "-uall").lines.filter_map do |line|
    line = line.chomp
    next if line.empty?

    status = line[0, 2].strip
    path = line[3..].strip.delete_prefix('"').delete_suffix('"')
    [status, path]
  end
end

def describe_path(path)
  case path
  when %r{\Adb/migrate/}
    "database migration"
  when %r{\Adb/schema\.rb\z}
    "generated database schema"
  when %r{\Aspec/}
    "test"
  when %r{\Aapp/controllers/}
    "controller"
  when %r{\Aapp/models/}
    "model"
  when %r{\Aapp/jobs/}
    "background job"
  when %r{\Aapp/policies/}
    "authorization policy"
  when %r{\Aapp/controllers/concerns/}
    "controller concern"
  when %r{\Alib/tribetip/}
    "service library"
  when %r{\Aconfig/routes\.rb\z}
    "API routes"
  when %r{\Aconfig/}
    "configuration"
  when %r{\AGemfile\z}
    "Ruby dependencies"
  when %r{\AGemfile\.lock\z}
    "locked Ruby dependency versions"
  when %r{\A\.env\.example\z}
    "environment variable documentation"
  when %r{\Ascripts/}
    "script"
  else
    "file"
  end
end

def extract_changes(diff)
  added = diff.lines.filter_map { |l| l[1..] if l.start_with?("+") && !l.start_with?("+++") }
  removed = diff.lines.filter_map { |l| l[1..] if l.start_with?("-") && !l.start_with?("---") }

  notes = []

  added.grep(/^\s*(class|module)\s+(\w+)/) { |l| notes << "Introduce #{l.strip.split[1]}." }
  added.grep(/^\s*def\s+(\w+)/) { |l| notes << "Add #{l.strip.split[1]} method." }
  added.grep(/^\s*(get|post|patch|put|delete)\s+/) { |l| notes << "Register route: #{l.strip}." }
  added.grep(/create_table\s+:(\w+)/) { |l| notes << "Create #{l[/:(\w+)/, 1]} table." }
  added.grep(/add_column\s+:(\w+)/) { |l| notes << "Add column on #{l[/:(\w+)/, 1]}." }
  added.grep(/add_index\s+:(\w+)/) { |l| notes << "Add index on #{l[/:(\w+)/, 1]}." }
  added.grep(/has_paper_trail/) { notes << "Enable PaperTrail versioning." }
  added.grep(/belongs_to\s+:(\w+)/) { |l| notes << "Associate with #{l[/:(\w+)/, 1]}." }
  added.grep(/has_many\s+:(\w+)/) { |l| notes << "Add #{l[/:(\w+)/, 1]} association." }
  added.grep(/retry_on\s+/) { notes << "Add job retry handling." }
  added.grep(/around_perform/) { notes << "Wrap job execution with shared context." }
  added.grep(/include\s+(\w+)/) { |l| notes << "Include #{l.strip.split[1]}." }
  added.grep(/before_action\s+:(\w+)/) { |l| notes << "Add before_action #{l[/:(\w+)/, 1]}." }
  added.grep(/validates\s+:(\w+)/) { |l| notes << "Validate #{l[/:(\w+)/, 1]}." }
  added.grep(/scope\s+:(\w+)/) { |l| notes << "Add #{l[/:(\w+)/, 1]} scope." }

  removed.grep(/^\s*def\s+(\w+)/) { |l| notes << "Remove #{l.strip.split[1]} method." }

  if added.any? { |l| l.include?("paid_via") }
    notes << "Track how tips were marked paid."
  end
  if added.any? { |l| l.include?("failed_reason") }
    notes << "Store failure reasons on tips."
  end
  if added.any? { |l| l.include?("tip_events") || l.include?("TipEvent") }
    notes << "Record tip lifecycle audit events."
  end
  if added.any? { |l| l.include?("admin_audit_logs") || l.include?("AdminAuditLog") }
    notes << "Record attributed admin actions."
  end
  if added.any? { |l| l.include?("InvestigateTip") || l.include?("investigate") }
    notes << "Support admin tip investigation."
  end
  if added.any? { |l| l.include?("PaymentLogger") || l.include?("audit/payment") }
    notes << "Add structured payment audit logging."
  end
  if added.any? { |l| l.include?("invalidate_cache") || l.include?("refresh:") }
    notes << "Improve payout cache invalidation and refresh behavior."
  end
  if added.any? { |l| l.include?("ReconcilePendingTipsJob") }
    notes << "Sweep stale pending tips on a schedule."
  end
  if added.any? { |l| l.include?("RetryFailedWebhookEventsJob") }
    notes << "Retry failed Paystack webhook events on a schedule."
  end
  if added.any? { |l| l.include?("record_admin_audit!") }
    notes << "Log privileged admin actions."
  end

  notes.uniq
end

def summarize_diff(path, diff, deleted: false)
  kind = describe_path(path)

  return "Remove #{path}.\n\nDelete this #{kind} and its related functionality from the project." if deleted

  if diff.empty?
    return "Add #{path}.\n\nIntroduce a new #{kind} for the TribeTip platform."
  end

  added = diff.lines.count { |l| l.start_with?("+") && !l.start_with?("+++") }
  removed = diff.lines.count { |l| l.start_with?("-") && !l.start_with?("---") }
  hunks = diff.lines.grep(/^@@ /).size

  lines = ["Update #{path}."]
  lines << ""
  lines << "Modify this #{kind} (#{hunks} edited section#{'s' if hunks != 1}, #{added} additions, #{removed} removals)."

  changes = extract_changes(diff)
  if changes.any?
    lines << ""
    lines << "What changed:"
    changes.first(12).each { |note| lines << "- #{note}" }
  else
    lines << ""
    lines << "What changed:"
    lines << "- Adjust implementation and supporting logic in this #{kind}."
  end

  lines.join("\n")
end

files = porcelain_files
raise "No files to commit" if files.empty?

files.each do |status, path|
  if status == "D"
    git("rm", "-f", path)
    message = summarize_diff(path, "", deleted: true)
  else
    git("add", "--", path)
    diff = git("diff", "--cached", "--", path)
    message = summarize_diff(path, diff)
  end

  git("commit", "-m", message)
  puts "committed: #{path}"
end

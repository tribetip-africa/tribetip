# frozen_string_literal: true

def format_paystack_remote(remote)
  return "not stored" if remote[:code].blank?

  status = remote[:verified] ? "verified" : "failed"
  "#{remote[:code]} (#{status})"
end

namespace :paystack do
  desc "Audit Paystack onboarding for a creator (username). Set SYNC=1 to reconcile local state."
  task :audit, [ :username ] => :environment do |_task, args|
    username = args[:username].to_s.strip.downcase
    abort "Usage: bin/rails paystack:audit[username]" if username.blank?

    tribe = Tribe.find_by(username: username)
    abort "Tribe not found: #{username}" if tribe.nil?

    sync = ENV["SYNC"] == "1"
    report = Tribetip::Paystack::AuditOnboarding.call(tribe, sync: sync)

    puts "Paystack audit for @#{report.username} (#{report.market.name}, #{report.market.currency})"
    puts "Healthy: #{report.healthy ? 'yes' : 'no'}"
    puts "Customer ready: #{report.customer_ready ? 'yes' : 'no'}"
    puts "Subaccount ready: #{report.subaccount_ready ? 'yes' : 'no'}"
    puts "Onboarding complete: #{report.onboarding_complete ? 'yes' : 'no'}"
    puts
    puts "Local"
    puts "  customer_code: #{report.local[:customer_code] || '(none)'}"
    puts "  subaccount_code: #{report.local[:subaccount_code] || '(none)'}"
    puts "  onboarding_completed_at: #{report.local[:onboarding_completed_at] || '(none)'}"
    puts
    puts "Remote"
    puts "  customer: #{format_paystack_remote(report.remote[:customer])}"
    puts "  subaccount: #{format_paystack_remote(report.remote[:subaccount])}"
    puts
    puts "Checks"
    report.checks.each do |entry|
      puts "  [#{entry.status}] #{entry.name}: #{entry.message}"
    end

    exit(report.healthy ? 0 : 1)
  end

  desc "Reconcile a pending tip with Paystack (paystack_reference). Set REF=tip_..."
  task reconcile_tip: :environment do
    reference = ENV["REF"].to_s.strip
    abort "Usage: REF=tip_abc bin/rails paystack:reconcile_tip" if reference.blank?

    tip = Tip.find_by!(paystack_reference: reference)
    result = Tribetip::Paystack::ReconcileTipPayment.call(tip)

    puts "Tip #{reference}: #{tip.reload.status}"
    if result.success?
      puts "Reconciled successfully."
      puts "  paid_at: #{tip.paid_at}"
    else
      puts "Not reconciled: #{result.message}"
      exit 1
    end
  end
end

# frozen_string_literal: true

username = ENV.fetch("SIMULATE_SETTLEMENT_USERNAME", "bing")
amount_arg = ENV["SIMULATE_SETTLEMENT_AMOUNT_CENTS"].to_s

tribe = Tribe.find_by!(username: username)
paid_tips = tribe.tips.paid.order(paid_at: :desc)
linked_tip = paid_tips.first
raise "No paid tips for @#{tribe.username} — record a tip first, then simulate settlement." unless linked_tip

transfer_code = Tribetip::Paystack::SettlementRecord.transfer_code_for_tip(linked_tip)
existing = tribe.paystack_settlements.find_by(tip_id: linked_tip.id) ||
           PaystackSettlement.find_by(paystack_transfer_code: transfer_code)

if existing&.status == "success"
  puts "Settlement already recorded for @#{tribe.username}"
  puts "  transfer_code: #{existing.paystack_transfer_code}"
  puts "  linked_tip:    #{linked_tip.paystack_reference}"
  puts ""
  puts "No duplicate created. Re-run Paystack sync or repair if you need to reconcile remote data."
  exit 0
end

gross_paid = paid_tips.sum(:amount_cents)
amount_cents = amount_arg.present? ? amount_arg.to_i : Tribetip::Paystack::SettlementRecord.net_settlement_cents(gross_paid)
amount_cents = Tribetip::Paystack::SettlementRecord.net_settlement_cents(linked_tip.amount_cents) if amount_cents <= 0

payout = Tribetip::Paystack::FetchPayoutStatus.call(tribe, refresh: false)
destination = [ payout.settlement_bank, payout.account_number ].compact.join(" · ").presence || "M-PESA · ••••6789"

result = Tribetip::Paystack::RecordSettlement.call(
  payload: {
    transfer_code: transfer_code,
    amount: amount_cents,
    currency: tribe.currency,
    status: "success",
    reference: linked_tip.paystack_reference,
    createdAt: Time.current.iso8601,
    metadata: {
      tribe_id: tribe.id,
      username: tribe.username,
      subaccount_code: tribe.paystack_subaccount_code,
      tip_id: linked_tip.id,
      source: "simulate-settlement"
    },
    recipient: {
      details: {
        account_number: payout.account_number,
        bank_name: payout.settlement_bank
      }
    }
  },
  event_type: "transfer.success"
)

settlement = result.settlement
raise "Settlement was skipped — check tribe subaccount / payload" unless settlement

Tribetip::Notifications::RecordSettlement.call(settlement, event_type: "transfer.success") if settlement.previously_new_record?

units = format("%.2f", amount_cents / 100.0)
notification = tribe.creator_notifications.order(created_at: :desc).first
puts "Simulated settlement for @#{tribe.username}"
puts "  transfer_code: #{settlement.paystack_transfer_code}"
puts "  amount:        #{units} #{settlement.currency}"
puts "  linked_tip:    #{linked_tip.paystack_reference}"
puts "  notification:  #{notification&.title || '(none)'}"
puts ""
puts "Check dashboard → Notifications and Payouts."

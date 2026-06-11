# frozen_string_literal: true

module Paystack
  class NotifySettlementJob < ApplicationJob
    queue_as :default

    def perform(settlement_id, event_type)
      settlement = PaystackSettlement.find_by(id: settlement_id)
      return unless settlement

      case settlement.status
      when "success"
        SettlementMailer.settlement_paid(settlement).deliver_now
      when "failed", "reversed"
        SettlementMailer.settlement_failed(settlement, event_type: event_type).deliver_now
      end

      Tribetip::Notifications::RecordSettlement.call(settlement, event_type: event_type)
    end
  end
end

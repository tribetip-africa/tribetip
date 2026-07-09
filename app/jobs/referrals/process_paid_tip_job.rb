# frozen_string_literal: true

module Referrals
  class ProcessPaidTipJob < ApplicationJob
    queue_as :default

    def perform(tip_id:)
      tip = Tip.find_by(id: tip_id)
      return unless tip&.paid?

      Tribetip::Referrals::Qualify.call(tip)
      Tribetip::Referrals::ConsumeFeeCredit.call(tip)
    end
  end
end

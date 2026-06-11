# frozen_string_literal: true

class SettlementMailer < ApplicationMailer
  default from: ENV.fetch("DEVISE_MAILER_SENDER", "no-reply@tribetip.africa")

  def settlement_paid(settlement)
    @settlement = settlement
    @tribe = settlement.tribe
    @dashboard_url = "#{Tribetip::Platform.app_url}/dashboard/payouts"

    mail(
      to: @tribe.email,
      subject: "Settlement sent to your payout account"
    )
  end

  def settlement_failed(settlement, event_type:)
    @settlement = settlement
    @tribe = settlement.tribe
    @event_type = event_type
    @dashboard_url = "#{Tribetip::Platform.app_url}/dashboard/payouts"

    mail(
      to: @tribe.email,
      subject: "Settlement issue on your TribeTip payout account"
    )
  end
end

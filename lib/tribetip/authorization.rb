# frozen_string_literal: true

module Tribetip
  module Authorization
    FORBIDDEN_MESSAGES = {
      manage_widget?: "Website widgets are not available for admin accounts.",
      manage_share_link?: "Share links are not available for admin accounts.",
      access_notifications?: "Notifications are not available for admin accounts.",
      access_paystack_onboarding?: "Paystack onboarding is not available for admin accounts.",
      access_paystack_withdrawals?: "Paystack withdrawals are not available for admin accounts.",
      access_paystack_settlements?: "Paystack settlements are not available for admin accounts.",
      access_paystack_repair?: "Paystack repair is not available for admin accounts."
    }.freeze

    module_function

    def error_for(exception)
      query = exception.query

      return Tribetip::Errors::OnboardingRequired.new if query == :access_dashboard?

      message = FORBIDDEN_MESSAGES[query]
      return Tribetip::Errors::BadRequest.new(message) if message

      Tribetip::Errors::Authorization.new
    end
  end
end

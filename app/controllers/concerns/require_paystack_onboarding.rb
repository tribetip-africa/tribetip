# frozen_string_literal: true

module RequirePaystackOnboarding
  extend ActiveSupport::Concern

  included do
    before_action :require_paystack_onboarding!
  end

  private

  def require_paystack_onboarding!
    return unless current_tribe
    return if current_tribe.admin?
    return if current_tribe.paystack_onboarding_complete?

    render_error(Tribetip::Errors::OnboardingRequired.new)
  end
end

# frozen_string_literal: true

module Tribetip
  module Authorization
    module Rules
      module Paystack
        module_function

        def payout_ready?(tribe)
          return false unless tribe

          tribe.paystack_onboarding_complete? || tribe.paystack_payout_linked?
        end

        def dashboard_access?(ctx)
          return true if ctx.admin?

          ctx.creator? && payout_ready?(ctx.subject)
        end
      end
    end
  end
end

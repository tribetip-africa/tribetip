# frozen_string_literal: true

module Admin
  class TipsController < BaseController
    def investigate
      apply_http_cache_policy(:no_store)

      investigation = Tribetip::Audit::InvestigateTip.call(params[:paystack_reference])

      render json: { investigation: investigation }
    end
  end
end

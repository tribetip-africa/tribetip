# frozen_string_literal: true

module Me
  class ProfilesController < ApplicationController
    before_action :authenticate_tribe!
    include RequireCreatorDashboard

    def show
      authorize current_tribe, :show?
      current_tribe.mark_paystack_onboarding_complete!
      apply_http_cache_policy(:no_store)
      render json: { profile: owner_profile_json(current_tribe.reload) }
    end

    def update
      authorize current_tribe, :update?
      apply_http_cache_policy(:no_store)

      if current_tribe.update(profile_params)
        render json: { profile: owner_profile_json(current_tribe) }
      else
        render_error(
          Tribetip::Errors::Validation.new(
            "Validation failed.",
            details: { errors: current_tribe.errors.full_messages }
          )
        )
      end
    end

    def publish
      payout = Tribetip::Paystack::FetchPayoutStatus.call(current_tribe, refresh: true)
      unless payout.subaccount_verified
        return render_error(
          Tribetip::Errors::SubaccountNotVerified.new(
            payout.publish_blocker.presence
          )
        )
      end

      authorize current_tribe, :publish?
      apply_http_cache_policy(:no_store)

      current_tribe.is_profile_public = true
      if current_tribe.save
        render json: {
          message: "Profile published.",
          profile: owner_profile_json(current_tribe)
        }
      else
        render_error(
          Tribetip::Errors::Validation.new(
            "Validation failed.",
            details: { errors: current_tribe.errors.full_messages }
          )
        )
      end
    end

    private

    def profile_params
      params.require(:profile).permit(
        :display_name,
        :bio,
        :country_code,
        :currency,
        :default_tip_amount_cents
      )
    end
  end
end

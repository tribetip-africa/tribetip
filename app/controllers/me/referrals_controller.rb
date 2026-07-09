# frozen_string_literal: true

module Me
  class ReferralsController < ApplicationController
    before_action :authenticate_tribe!
    include RequireCreatorDashboard

    def show
      authorize current_tribe, :access_referrals?
      apply_http_cache_policy(:no_store)

      render json: {
        referrals: Tribetip::Referrals::BuildSummary.call(current_tribe)
      }
    end

    def update
      authorize current_tribe, :manage_referrals?
      apply_http_cache_policy(:no_store)

      referrals_params = referral_settings_params
      unless referrals_params.key?(:referrals_enabled)
        return render_error(
          Tribetip::Errors::Validation.new("referrals_enabled is required.")
        )
      end

      result = Tribetip::Referrals::UpdateSettings.call(
        tribe: current_tribe,
        referrals_enabled: referrals_params[:referrals_enabled]
      )

      if result[:success]
        render json: { referrals: result[:referrals] }
      else
        render_error(
          Tribetip::Errors::Validation.new(
            "Validation failed.",
            details: { errors: result[:errors] }
          )
        )
      end
    rescue ArgumentError => e
      render_error(Tribetip::Errors::Validation.new(e.message))
    end

    def rotate_invite
      authorize current_tribe, :manage_referrals?
      apply_http_cache_policy(:no_store)

      unless current_tribe.referrals_enabled?
        return render_error(
          Tribetip::Errors::Validation.new("Referrals are turned off for your account.")
        )
      end

      invite = Tribetip::Referrals::Invites.rotate!(current_tribe)

      render json: {
        message: "Referral invite rotated. Previous codes and links no longer work.",
        invite: Tribetip::Referrals::Invites.payload_for(invite)
      }
    end

    private

    def referral_settings_params
      params.require(:referrals).permit(:referrals_enabled)
    end
  end
end

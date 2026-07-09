# frozen_string_literal: true

module Admin
  class ReferralsController < BaseController
    def index
      authorize Referral, :index?

      apply_http_cache_policy(:no_store)
      render json: Tribetip::Referrals::AdminOverview.call(
        limit: page_limit,
        offset: page_offset
      )
    end

    def reject
      referral = Referral.find(params[:id])
      authorize referral, :reject?

      reason = params[:reason].to_s.strip
      if reason.blank?
        return render_error(
          Tribetip::Errors::Validation.new("Validation failed.", details: { errors: [ "Reason is required" ] })
        )
      end

      unless Tribetip::Referrals::Reject.call(referral, reason: reason, actor_id: current_tribe.id)
        return render_error(Tribetip::Errors::BadRequest.new("Referral cannot be rejected."))
      end

      record_admin_audit!(
        action: "reject_referral",
        target: referral,
        details: { reason: reason }
      )

      render json: {
        message: "Referral rejected.",
        referral: referral_payload(referral.reload)
      }
    end

    private

    def page_limit
      [ params.fetch(:limit, 50).to_i, 100 ].min
    end

    def page_offset
      [ params.fetch(:offset, 0).to_i, 0 ].max
    end

    def referral_payload(referral)
      {
        id: referral.id,
        status: referral.status,
        referrer_username: referral.referrer.username,
        referred_username: referral.referred.username,
        qualified_at: referral.qualified_at&.iso8601,
        rewarded_at: referral.rewarded_at&.iso8601,
        metadata: referral.metadata
      }
    end
  end
end

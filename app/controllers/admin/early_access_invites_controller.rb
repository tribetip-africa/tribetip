# frozen_string_literal: true

module Admin
  class EarlyAccessInvitesController < BaseController
    def index
      authorize EarlyAccessInvite, :index?

      apply_http_cache_policy(:no_store)
      invites = EarlyAccessInvite.order(created_at: :desc).limit(page_limit).offset(page_offset)

      render json: {
        invites: invites.map { |invite| Tribetip::EarlyAccess::Invites.payload_for(invite) }
      }
    end

    def create
      authorize EarlyAccessInvite, :create?

      apply_http_cache_policy(:no_store)

      invite = Tribetip::EarlyAccess::Invites.create!(
        email: params.require(:email),
        expires_in_days: params[:expires_in_days]
      )

      record_admin_audit!(
        action: "create_early_access_invite",
        target: invite,
        details: { email: invite.email }
      )

      render json: {
        message: "Early access invite created.",
        invite: Tribetip::EarlyAccess::Invites.payload_for(invite)
      }, status: :created
    rescue ArgumentError => e
      render_error(Tribetip::Errors::Validation.new(e.message, details: { errors: [ e.message ] }))
    end

    def revoke
      invite = EarlyAccessInvite.find(params[:id])
      authorize invite, :revoke?

      apply_http_cache_policy(:no_store)
      Tribetip::EarlyAccess::Invites.revoke!(invite)

      record_admin_audit!(
        action: "revoke_early_access_invite",
        target: invite,
        details: { email: invite.email }
      )

      render json: {
        message: "Early access invite revoked.",
        invite: Tribetip::EarlyAccess::Invites.payload_for(invite.reload)
      }
    end

    private

    def page_limit
      [ params.fetch(:limit, 50).to_i, 100 ].min
    end

    def page_offset
      [ params.fetch(:offset, 0).to_i, 0 ].max
    end
  end
end

# frozen_string_literal: true

class EarlyAccessInvitesController < ApplicationController
  include SecureHttpCaching
  include Tribetip::Errors::Handler

  def show
    apply_http_cache_policy(:no_store)

    invite = Tribetip::EarlyAccess::Invites.resolve(params[:token].to_s)
    raise Tribetip::Errors::NotFound.new("Invite not found.") unless invite

    render json: {
      email: invite.email,
      expires_at: invite.expires_at.iso8601
    }
  end
end

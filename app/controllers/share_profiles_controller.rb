# frozen_string_literal: true

class ShareProfilesController < ApplicationController
  include PublicProfileRenderable

  def show
    token = params[:token].to_s
    raise ActiveRecord::RecordNotFound unless Tribetip::ShareLinks.valid_token_format?(token)
    raise ActiveRecord::RecordNotFound if Tribetip::ShareLinks.revoked?(token)

    tribe = Tribetip::ShareLinks.resolve_profile(token)
    raise ActiveRecord::RecordNotFound unless tribe

    render_share_public_profile(tribe)
  end
end

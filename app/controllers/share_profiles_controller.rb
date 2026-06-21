# frozen_string_literal: true

class ShareProfilesController < ApplicationController
  include PublicProfileRenderable

  def show
    tribe = Tribetip::ShareLinks.resolve_profile(params[:token].to_s)
    raise ActiveRecord::RecordNotFound unless tribe

    render_public_profile(tribe)
  end
end

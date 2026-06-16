# frozen_string_literal: true

class PublicProfilesController < ApplicationController
  include PublicProfileRenderable

  def show
    username = params[:username].to_s.downcase
    tribe = Tribe.find_by(username: username)
    raise ActiveRecord::RecordNotFound unless tribe
    raise ActiveRecord::RecordNotFound unless cacheable_public_profile?(tribe)

    render_public_profile(tribe)
  end
end

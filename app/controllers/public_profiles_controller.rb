# frozen_string_literal: true

class PublicProfilesController < ApplicationController
  def show
    apply_http_cache_policy(
      request.headers["Authorization"].present? ? :private_no_store : :public_short
    )

    username = params[:username].to_s.downcase
    payload = Tribetip::SecureCache.fetch(
      Tribetip::SecureCache.public_profile_key(username),
      scope: :public
    ) do
      tribe = Tribe.find_by(username: username)
      raise ActiveRecord::RecordNotFound if tribe.nil?
      raise ActiveRecord::RecordNotFound unless cacheable_public_profile?(tribe)

      public_profile_json(tribe)
    end

    render json: { profile: payload }
  end

  private

  def cacheable_public_profile?(tribe)
    tribe.is_profile_public? && tribe.account_status == "active"
  end

  def public_profile_json(tribe)
    {
      id: tribe.id,
      username: tribe.username,
      display_name: tribe.display_name,
      bio: tribe.bio,
      country_code: tribe.country_code,
      currency: tribe.currency,
      default_tip_amount_cents: tribe.default_tip_amount_cents
    }
  end
end

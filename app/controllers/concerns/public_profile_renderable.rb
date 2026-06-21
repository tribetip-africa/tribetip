# frozen_string_literal: true

module PublicProfileRenderable
  extend ActiveSupport::Concern

  private

  def render_public_profile(tribe)
    apply_http_cache_policy(
      request.headers["Authorization"].present? ? :private_no_store : :public_short
    )

    payload = Tribetip::SecureCache.fetch(
      public_profile_cache_key(tribe),
      scope: :public
    ) do
      public_profile_json(tribe)
    end

    render json: { profile: payload }
  end

  def public_profile_cache_key(tribe)
    if tribe.tip_share_token.present? && params[:token].present?
      Tribetip::ShareLinks.cache_key_for(params[:token])
    else
      Tribetip::SecureCache.public_profile_key(tribe.username)
    end
  end

  def cacheable_public_profile?(tribe)
    Tribetip::ShareLinks.shareable?(tribe)
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

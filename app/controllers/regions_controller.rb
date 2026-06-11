# frozen_string_literal: true

class RegionsController < ApplicationController
  include SecureHttpCaching

  def index
    apply_http_cache_policy(:public_short)
    render json: {
      default_country_code: Tribetip::Regions.default_country_code,
      regions: Tribetip::Regions.as_json
    }
  end
end

# frozen_string_literal: true

class SitemapCreatorsController < ApplicationController
  include SecureHttpCaching

  def index
    apply_http_cache_policy(:public_short)
    render json: Tribetip::PublicSitemap.list(
      page: params[:page],
      per_page: params[:per_page]
    )
  end
end

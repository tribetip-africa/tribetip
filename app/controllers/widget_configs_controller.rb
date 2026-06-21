# frozen_string_literal: true

class WidgetConfigsController < ApplicationController
  def show
    apply_http_cache_policy(:public_short)

    token = params[:token].to_s
    raise ActiveRecord::RecordNotFound unless Tribetip::WidgetEmbed.valid_token_format?(token)
    raise ActiveRecord::RecordNotFound if Tribetip::WidgetEmbed.revoked?(token)

    config = Tribetip::WidgetEmbed.resolve_config(token)
    raise ActiveRecord::RecordNotFound unless config

    render json: { config: config }
  end
end

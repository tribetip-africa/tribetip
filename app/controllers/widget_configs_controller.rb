# frozen_string_literal: true

class WidgetConfigsController < ApplicationController
  def show
    apply_http_cache_policy(:public_short)

    config = Tribetip::WidgetEmbed.resolve_config(params[:token].to_s)
    raise ActiveRecord::RecordNotFound unless config

    render json: { config: config }
  end
end

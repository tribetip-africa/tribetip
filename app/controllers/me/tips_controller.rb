# frozen_string_literal: true

module Me
  class TipsController < ApplicationController
    include TipSerializable
    include RequirePaystackOnboarding

    before_action :authenticate_tribe!

    def index
      tips = policy_scope(Tip).recent_first
      apply_http_cache_policy(:no_store)
      render json: { tips: tips.map { |tip| tip_json(tip) } }
    end

    def show
      tip = Tip.find(params[:id])
      authorize tip
      apply_http_cache_policy(:no_store)
      render json: { tip: tip_json(tip) }
    end
  end
end

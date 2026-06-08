# frozen_string_literal: true

module Admin
  class TribesController < BaseController
    include AdminTribeSerializable

    before_action :set_tribe, only: %i[suspend activate]

    def index
      apply_http_cache_policy(:no_store)
      tribes = filtered_tribes.limit(page_limit).offset(page_offset)
      tip_stats = Tribetip::Metrics::TribeTipStats.for_tribes(tribes)

      render json: {
        overview: admin_overview_json,
        tribes: tribes.map { |tribe| admin_tribe_json(tribe, tip_stats: tip_stats) },
        pagination: {
          limit: page_limit,
          offset: page_offset,
          total: filtered_tribes.count
        }
      }
    end

    def suspend
      authorize @tribe, :suspend?

      @tribe.update!(account_status: "suspended")
      record_admin_audit!(action: "suspend_tribe", target: @tribe)

      render json: {
        message: "Tribe suspended.",
        tribe: admin_tribe_json(@tribe, tip_stats: tip_stats_for(@tribe))
      }, status: :ok
    end

    def activate
      authorize @tribe, :activate?

      @tribe.update!(account_status: "active")
      record_admin_audit!(action: "activate_tribe", target: @tribe)

      render json: {
        message: "Tribe activated.",
        tribe: admin_tribe_json(@tribe, tip_stats: tip_stats_for(@tribe))
      }, status: :ok
    end

    private

    def set_tribe
      @tribe = Tribe.find(params[:id])
    end

    def filtered_tribes
      scope = Tribe.order(created_at: :desc)
      query = params[:q].to_s.strip.downcase
      return scope if query.blank?

      scope.where(
        "LOWER(username) LIKE :query OR LOWER(email) LIKE :query",
        query: "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      )
    end

    def page_limit
      [ [ params.fetch(:limit, 25).to_i, 1 ].max, 100 ].min
    end

    def page_offset
      [ params.fetch(:offset, 0).to_i, 0 ].max
    end

    def tip_stats_for(tribe)
      Tribetip::Metrics::TribeTipStats.for_tribes([ tribe ])
    end
  end
end

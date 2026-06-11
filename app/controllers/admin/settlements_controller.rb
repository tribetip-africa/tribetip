# frozen_string_literal: true

module Admin
  class SettlementsController < BaseController
    before_action :set_tribe

    def index
      authorize @tribe, :audit_paystack?

      apply_http_cache_policy(:no_store)
      refresh = ActiveModel::Type::Boolean.new.cast(params[:refresh])
      result = Tribetip::Paystack::ListSettlements.call(@tribe, refresh: refresh)

      render json: {
        tribe_id: @tribe.id,
        username: @tribe.username,
        settlements: result.settlements.map(&:as_json),
        summary: Tribetip::Metrics::SettlementSummary.call(@tribe).as_json,
        source: result.source,
        refreshed_at: result.refreshed_at.iso8601,
        synced_at: result.synced_at&.iso8601
      }
    end

    private

    def set_tribe
      @tribe = Tribe.find(params[:id])
    end
  end
end

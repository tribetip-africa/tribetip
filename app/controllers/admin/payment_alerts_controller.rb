# frozen_string_literal: true

module Admin
  class PaymentAlertsController < BaseController
    def index
      authorize PaymentAlert, :index?

      apply_http_cache_policy(:no_store)

      alerts = policy_scope(PaymentAlert).recent_first
      alerts = alerts.unresolved if ActiveModel::Type::Boolean.new.cast(params[:unresolved])

      render json: {
        alerts: alerts.limit(page_limit).offset(page_offset).map(&:as_json),
        pagination: {
          limit: page_limit,
          offset: page_offset,
          total: alerts.count
        }
      }
    end

    private

    def page_limit
      [ [ params.fetch(:limit, 25).to_i, 1 ].max, 100 ].min
    end

    def page_offset
      [ params.fetch(:offset, 0).to_i, 0 ].max
    end
  end
end

# frozen_string_literal: true

module Me
  module Paystack
    class SettlementsController < ApplicationController
      before_action :authenticate_tribe!
      before_action :authorize_paystack_settlements!

      def index
        apply_http_cache_policy(:no_store)
        refresh = ActiveModel::Type::Boolean.new.cast(params[:refresh])
        result = Tribetip::Paystack::ListSettlements.call(current_tribe, refresh: refresh)

        render json: {
          settlements: result.settlements.map(&:as_json),
          summary: Tribetip::Metrics::SettlementSummary.call(current_tribe).as_json,
          source: result.source,
          refreshed_at: result.refreshed_at.iso8601,
          synced_at: result.synced_at&.iso8601
        }
      end

      def show
        apply_http_cache_policy(:no_store)
        settlement = current_tribe.paystack_settlements.find_by!(paystack_transfer_code: params[:id])
        detail = Tribetip::Paystack::BuildSettlementDetail.call(settlement)

        render json: detail.as_json
      end

      private

      def authorize_paystack_settlements!
        authorize current_tribe, :access_paystack_settlements?
      end
    end
  end
end

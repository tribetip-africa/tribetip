# frozen_string_literal: true

module Admin
  module Paystack
    class ReconciliationsController < BaseController
      def show
        apply_http_cache_policy(:no_store)

        report = Tribetip::SecureCache.read(
          Tribetip::Paystack::ReconcilePlatform::REPORT_CACHE_KEY,
          scope: :private
        )

        render json: {
          reconciliation: report || {
            status: "never_run",
            message: "No platform reconciliation has completed yet."
          }
        }
      end

      def create
        apply_http_cache_policy(:no_store)

        if async_requested?
          Paystack::ReconcilePlatformJob.perform_later(auto_repair: repair_requested?)

          render json: {
            message: "Platform reconciliation enqueued.",
            auto_repair: repair_requested?
          }, status: :accepted
          return
        end

        report = Tribetip::Paystack::ReconcilePlatform.call(auto_repair: repair_requested?)

        record_admin_audit!(
          action: "platform_reconciliation_run",
          target: current_tribe,
          details: report.summary
        )

        render json: { reconciliation: report.as_json }
      end

      private

      def repair_requested?
        !params.key?(:auto_repair) || ActiveModel::Type::Boolean.new.cast(params[:auto_repair])
      end

      def async_requested?
        ActiveModel::Type::Boolean.new.cast(params[:async])
      end
    end
  end
end

# frozen_string_literal: true

module Admin
  module Paystack
    class AuditsController < BaseController
      before_action :set_tribe

      def show
        authorize @tribe, :audit_paystack?

        apply_http_cache_policy(:no_store)
        report = Tribetip::Paystack::AuditOnboarding.call(@tribe, sync: sync_requested?)

        if sync_requested?
          record_admin_audit!(
            action: "paystack_audit_sync",
            target: @tribe,
            details: {
              healthy: report.healthy,
              onboarding_complete: report.onboarding_complete
            }
          )
        end

        render json: { audit: report.as_json }
      end

      private

      def set_tribe
        @tribe = policy_scope(Tribe).find(params[:id])
      end

      def sync_requested?
        ActiveModel::Type::Boolean.new.cast(params[:sync])
      end
    end
  end
end

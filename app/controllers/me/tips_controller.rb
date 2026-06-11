# frozen_string_literal: true

module Me
  class TipsController < ApplicationController
    include TipSerializable
    include RequirePaystackOnboarding
    include AuditRequestContext

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

    def reconcile
      tip = Tip.find(params[:id])
      authorize tip, :reconcile?

      apply_http_cache_policy(:no_store)
      result = Tribetip::Paystack::ReconcileTipPayment.call(
        tip,
        paid_via: :reconcile,
        actor_id: current_tribe.id,
        request_context: audit_request_context
      )

      if result.success?
        render json: {
          message: "Tip payment reconciled with Paystack.",
          tip: tip_json(tip.reload)
        }
      else
        render json: {
          message: result.message,
          tip: tip_json(tip.reload)
        }, status: :accepted
      end
    end
  end
end

# frozen_string_literal: true

module Me
  module Paystack
    class WithdrawalsController < ApplicationController
      include Idempotable

      before_action :authenticate_tribe!
      before_action :ensure_creator_for_paystack!

      def index
        apply_http_cache_policy(:no_store)
        refresh = ActiveModel::Type::Boolean.new.cast(params[:refresh])
        status = Tribetip::Paystack::BuildWithdrawalStatus.call(current_tribe, refresh: refresh)
        withdrawals = recent_withdrawals

        render json: {
          status: status.as_json,
          withdrawals: withdrawals.map(&:to_settlement_record).map(&:as_json)
        }
      end

      def create
        apply_http_cache_policy(:no_store)

        if idempotency_key_header.present?
          cached = IdempotencyKey.find_active(scope: "paystack_withdrawal", key: idempotency_key_header)
          return render json: cached.response_body, status: cached.response_code if cached
        end

        result = Tribetip::Paystack::InitiateWithdrawal.call(
          current_tribe,
          actor_id: current_tribe.id
        )

        unless result.success?
          return render_error(Tribetip::Errors::BadRequest.new(result.message))
        end

        body = {
          message: result.message,
          withdrawal: result.settlement.to_settlement_record.as_json,
          status: result.status.as_json
        }

        if idempotency_key_header.present?
          IdempotencyKey.store!(
            scope: "paystack_withdrawal",
            key: idempotency_key_header,
            response_code: 200,
            response_body: body
          )
        end

        render json: body
      end

      private

      def recent_withdrawals
        current_tribe.paystack_settlements
                       .where("metadata->>'source' = ?", "manual_withdrawal")
                       .recent_first
                       .limit(10)
      end

      def ensure_creator_for_paystack!
        return if current_tribe.creator?

        render_error(
          Tribetip::Errors::BadRequest.new("Paystack withdrawals are not available for admin accounts.")
        )
      end
    end
  end
end

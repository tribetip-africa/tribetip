# frozen_string_literal: true

module Me
  module Paystack
    class WithdrawalsController < ApplicationController
      include Idempotable

      before_action :authenticate_tribe!
      before_action :authorize_paystack_withdrawals!

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
          cached = find_idempotency_cache("paystack_withdrawal")
          return if performed?
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
          store_idempotency_cache!(
            scope: "paystack_withdrawal",
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

      def authorize_paystack_withdrawals!
        authorize current_tribe, :access_paystack_withdrawals?
      end
    end
  end
end

# frozen_string_literal: true

module Me
  module Paystack
    class AccountNumbersController < ApplicationController
      include RequiresFreshPasswordSession

      before_action :authenticate_tribe!
      before_action :authorize_paystack_onboarding!
      require_fresh_password_session! only: :show

      def show
        apply_http_cache_policy(:no_store)

        account_number = Tribetip::Paystack::FetchAccountNumber.call(current_tribe)
        if account_number.blank?
          return render_error(
            Tribetip::Errors::NotFound.new("Payout account number is not available.")
          )
        end

        record_account_number_reveal!

        render json: { account_number: account_number }
      end

      private

      def authorize_paystack_onboarding!
        authorize current_tribe, :reveal_paystack_account_number?
      end

      def record_account_number_reveal!
        Tribetip::Audit::RecordTribeAction.call(
          tribe: current_tribe,
          action: "account_number_revealed",
          details: reveal_audit_details,
          request: request
        )
      end

      def reveal_audit_details
        code = current_tribe.paystack_subaccount_code.to_s
        {
          market: current_tribe.country_code,
          subaccount_code_suffix: code.last(4).presence
        }.compact
      end
    end
  end
end

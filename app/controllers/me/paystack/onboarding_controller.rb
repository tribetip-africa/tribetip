# frozen_string_literal: true

module Me
  module Paystack
    class OnboardingController < ApplicationController
      include Idempotable

      before_action :authenticate_tribe!
      before_action :ensure_creator_for_paystack!
      ONBOARDING_WAIT = ENV.fetch("TRIBETIP_ONBOARDING_WAIT_SECONDS", 10).to_i.seconds
      CUSTOMER_WAIT = ENV.fetch("TRIBETIP_CUSTOMER_WAIT_SECONDS", 5).to_i.seconds

      def show
        apply_http_cache_policy(:no_store)
        provision_customer_if_needed!
        wait_for_customer_if_needed!
        market = current_tribe.paystack_market
        status = Tribetip::Paystack::SyncOnboarding.call(current_tribe.reload)
        payout = Tribetip::Paystack::FetchPayoutStatus.call(current_tribe.reload, refresh: true)
        banks = Tribetip::Paystack::ListSettlementBanks.call(market)

        render json: {
          onboarding: status,
          payout: payout.as_json,
          market: market.as_json,
          banks: banks.map { |bank| bank.as_json(market: market) },
          earnings: Tribetip::Metrics::CreatorSummary.call(current_tribe).as_json,
          settlements_summary: Tribetip::Metrics::SettlementSummary.call(current_tribe).as_json,
          refreshed_at: Time.current.iso8601
        }
      end

      def create
        apply_http_cache_policy(:no_store)

        if idempotency_key_header.present?
          cached = find_idempotency_cache("paystack_onboarding")
          return if performed?
          return render json: cached.response_body, status: cached.response_code if cached
        end

        unless provision_subaccount!
          message = current_tribe.reload.paystack_provisioning_error.presence ||
            "Payout setup is still processing. Please wait a moment and refresh."
          return render_error(Tribetip::Errors::BadRequest.new(message))
        end

        market = current_tribe.paystack_market
        status = Tribetip::Paystack::SyncOnboarding.call(current_tribe.reload)
        body = {
          message: "Paystack payout account linked.",
          onboarding: status,
          market: market.as_json,
          tribe: tribe_json(current_tribe.reload)
        }

        if idempotency_key_header.present?
          store_idempotency_cache!(
            scope: "paystack_onboarding",
            response_code: 200,
            response_body: body
          )
        end

        render json: body
      end

      private

      def onboarding_params
        params.require(:onboarding).permit(:settlement_bank, :account_number, :business_name)
      end

      def provision_customer_if_needed!
        return unless current_tribe.paystack_sync_required?
        return if current_tribe.paystack_customer_code.present?
        return unless current_tribe.paystack_market.subaccount_supported?

        if paystack_client.stub_mode?
          result = Tribetip::Paystack::ProvisionCustomer.call(current_tribe)
          return if result.success?

          current_tribe.update!(paystack_provisioning_error: result.message)
          return
        end

        return if paystack_job_pending?(
          job_class: ::Paystack::ProvisionCustomerJob,
          arguments: [ current_tribe.id ]
        )

        ::Paystack::ProvisionCustomerJob.perform_later(current_tribe.id)
      end

      def provision_subaccount!
        if paystack_client.stub_mode?
          result = Tribetip::Paystack::ProvisionSubaccount.call(
            current_tribe,
            settlement_bank: onboarding_params[:settlement_bank],
            account_number: onboarding_params[:account_number],
            business_name: onboarding_params[:business_name]
          )
          return result.success?
        end

        ::Paystack::ProvisionSubaccountJob.perform_later(
          current_tribe.id,
          settlement_bank: onboarding_params[:settlement_bank],
          account_number: onboarding_params[:account_number],
          business_name: onboarding_params[:business_name]
        )

        wait_for_subaccount_link!
      end

      def paystack_client
        @paystack_client ||= Tribetip::Paystack::Client.new
      end

      def paystack_job_pending?(job_class:, arguments:)
        SolidQueue::Job.where(class_name: job_class.name, finished_at: nil)
          .where("arguments::jsonb -> 'arguments' = ?", arguments.to_json)
          .exists?
      rescue StandardError
        false
      end

      def wait_for_customer_if_needed!
        return unless current_tribe.paystack_market.subaccount_supported?
        return if current_tribe.paystack_customer_code.present?

        Tribetip::AsyncPoll.wait_until(max: CUSTOMER_WAIT) do
          current_tribe.reload
          if current_tribe.paystack_provisioning_error.present? && current_tribe.paystack_customer_code.blank?
            break :failed
          end
          current_tribe.paystack_customer_code.present? ? true : nil
        end
      end

      def wait_for_subaccount_link!
        Tribetip::AsyncPoll.wait_until(max: ONBOARDING_WAIT) do
          current_tribe.reload
          next true if current_tribe.paystack_subaccount_code.present?
          next false if current_tribe.paystack_provisioning_error.present?

          nil
        end == true
      end

      def ensure_creator_for_paystack!
        return if current_tribe.creator?

        render_error(
          Tribetip::Errors::BadRequest.new("Paystack onboarding is not available for admin accounts.")
        )
      end
    end
  end
end

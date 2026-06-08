# frozen_string_literal: true

module Tribetip
  module Paystack
    class ProvisionSubaccount
      Result = Struct.new(:success?, :subaccount_code, :message, keyword_init: true)

      def self.call(tribe, settlement_bank: nil, account_number: nil, business_name: nil)
        new(tribe).call(
          settlement_bank: settlement_bank,
          account_number: account_number,
          business_name: business_name
        )
      end

      def initialize(tribe)
        @tribe = tribe
        @client = Client.new
        @market = Market.for_tribe(tribe)
      end

      def call(settlement_bank:, account_number:, business_name:)
        @tribe.with_lock do
          @tribe.reload
          return success(@tribe.paystack_subaccount_code) if @tribe.paystack_subaccount_code.present?

          unless @tribe.paystack_customer_code.present?
            customer = ProvisionCustomer.call(@tribe)
            return Result.new(success?: false, message: customer.message) unless customer.success?

            @tribe.reload
          end

          unless @market.subaccount_supported?
            return Result.new(
              success?: false,
              message: "Paystack subaccounts are not yet supported for #{@market.name}."
            )
          end

          bank = settlement_bank.presence || (@client.stub_mode? ? @market.stub_settlement_bank : nil)
          account = account_number.presence || (@client.stub_mode? ? @market.stub_account_number : nil)
          account = SettlementAccount.normalize(
            account_number: account,
            settlement_bank: bank,
            market: @market
          )

          if bank.blank? || account.blank?
            return Result.new(success?: false, message: "Settlement bank and account number are required.")
          end

          response = @client.create_subaccount(
            business_name: business_name.presence || @tribe.display_name.presence || @tribe.username,
            settlement_bank: bank,
            account_number: account,
            percentage_charge: platform_fee_percent,
            primary_contact_email: @tribe.email,
            currency: @market.currency,
            metadata: @market.paystack_metadata_for(@tribe).merge(
              paystack_customer_code: @tribe.paystack_customer_code
            )
          )

          unless response.success?
            message = response.message || "Unable to create Paystack subaccount."
            @tribe.update!(paystack_provisioning_error: message)
            return Result.new(success?: false, message: message)
          end

          @tribe.update!(paystack_subaccount_code: response.code, paystack_provisioning_error: nil)
          @tribe.mark_paystack_onboarding_complete!

          Result.new(success?: true, subaccount_code: response.code)
        end
      rescue ActiveRecord::RecordNotUnique
        @tribe.reload
        success(@tribe.paystack_subaccount_code)
      end

      private

      def platform_fee_percent
        ENV.fetch("PAYSTACK_PLATFORM_FEE_PERCENT", "5").to_f
      end

      def success(code)
        Result.new(success?: true, subaccount_code: code)
      end
    end
  end
end

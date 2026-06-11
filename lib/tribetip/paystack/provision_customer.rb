# frozen_string_literal: true

module Tribetip
  module Paystack
    class ProvisionCustomer
      Result = Struct.new(:success?, :customer_code, :message, keyword_init: true)

      def self.call(tribe)
        new(tribe).call
      end

      def initialize(tribe)
        @tribe = tribe
        @client = Client.new
      end

      def call
        return skipped unless @tribe.paystack_sync_required?

        @tribe.with_lock do
          @tribe.reload
          return success(@tribe.paystack_customer_code) if @tribe.paystack_customer_code.present?

          market = Market.for_tribe(@tribe)
          response = @client.create_customer(
            email: @tribe.email,
            first_name: customer_first_name,
            metadata: market.paystack_metadata_for(@tribe)
          )

          unless response.success?
            message = response.message || "Unable to create Paystack customer."
            @tribe.update!(paystack_provisioning_error: message)
            return Result.new(success?: false, message: message)
          end

          @tribe.update!(paystack_customer_code: response.code, paystack_provisioning_error: nil)

          Result.new(success?: true, customer_code: response.code)
        end
      rescue ActiveRecord::RecordNotUnique
        @tribe.reload
        success(@tribe.paystack_customer_code)
      end

      private

      def customer_first_name
        @tribe.display_name.presence || @tribe.username
      end

      def success(code)
        Result.new(success?: true, customer_code: code)
      end

      def skipped
        Result.new(success?: true, customer_code: nil, message: "Paystack sync is not required for admin accounts.")
      end
    end
  end
end

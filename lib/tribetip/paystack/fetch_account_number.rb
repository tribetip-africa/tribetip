# frozen_string_literal: true

module Tribetip
  module Paystack
    class FetchAccountNumber
      def self.call(tribe)
        new(tribe).call
      end

      def initialize(tribe)
        @tribe = tribe
        @client = Client.new
        @market = Market.for_tribe(tribe)
      end

      def call
        return @market.stub_account_number if @client.stub_mode?
        return nil if @tribe.paystack_subaccount_code.blank?

        code = @tribe.paystack_subaccount_code
        return @market.stub_account_number if local_subaccount_code?(code)

        subaccount = @client.fetch_subaccount(code)
        return nil unless subaccount.success?

        data = subaccount.data
        return nil unless data.is_a?(Hash)

        data["account_number"].presence
      end

      def local_subaccount_code?(code)
        code.to_s.match?(/\Aacct_(seed|stub)_/i)
      end
    end
  end
end

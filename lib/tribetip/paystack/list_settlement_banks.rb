# frozen_string_literal: true

module Tribetip
  module Paystack
    class ListSettlementBanks
      def self.call(market, client: Client.new)
        new(market, client).call
      end

      def initialize(market, client)
        @market = market
        @client = client
      end

      def call
        return [] unless @market.subaccount_supported?

        payload = Tribetip::SecureCache.fetch(
          settlement_banks_cache_key,
          scope: :public,
          ttl: 24.hours
        ) do
          fetch_banks_from_paystack.map { |bank| bank.as_json(market: @market) }
        end

        payload
          .map { |row| bank_from_cache(row) }
          .select { |bank| bank.available_for_market?(@market) }
      end

      private

      def bank_from_cache(row)
        data = row.with_indifferent_access
        SettlementBank.new(
          name: data[:name],
          code: data[:code],
          type: data[:type],
          currency: data[:currency]
        )
      end

      def settlement_banks_cache_key
        "paystack_banks/#{@market.paystack_bank_country}/#{@market.currency}"
      end

      def fetch_banks_from_paystack
        response = @client.list_banks(paystack_bank_country: @market.paystack_bank_country)
        return [] unless response.success?

        SettlementBank.list_from(response.data, currency: @market.currency, market: @market)
      end
    end
  end
end

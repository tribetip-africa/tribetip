# frozen_string_literal: true

module Tribetip
  module Paystack
    class SettlementBank
      attr_reader :name, :code, :type, :currency

      def self.list_from(data, currency: nil, market: nil)
        banks = Array(data).filter_map { |row| from_paystack(row) }
        banks = banks.select { |bank| bank.currency == currency } if currency.present?
        banks = banks.select { |bank| bank.available_for_market?(market) } if market.present?
        banks.uniq(&:code)
      end

      def self.from_paystack(row)
        code = row["code"].to_s.presence
        name = row["name"].to_s.presence
        return if code.blank? || name.blank?

        new(
          name: name,
          code: code,
          type: row["type"].to_s.presence,
          currency: row["currency"].to_s.presence
        )
      end

      def initialize(name:, code:, type: nil, currency: nil)
        @name = name
        @code = code
        @type = type
        @currency = currency
      end

      def mobile_money_rail?
        SettlementAccount.mobile_money_bank?(code) || type.to_s.include?("mobile_money")
      end

      def available_for_market?(market)
        return true if market.blank?

        mobile_money_rail? ? market.mobile_money_supported? : true
      end

      def mobile_money?(market: nil)
        mobile_money_rail? && (market.blank? || market.mobile_money_supported?)
      end

      def as_json(market: nil, **_options)
        {
          name: name,
          code: code,
          type: type,
          currency: currency,
          mobile_money: mobile_money?(market: market)
        }.compact
      end
    end
  end
end

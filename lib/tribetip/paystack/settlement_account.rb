# frozen_string_literal: true

module Tribetip
  module Paystack
    class SettlementAccount
      MOBILE_MONEY_BANK_CODES = %w[MPESA MPPAYBILL MPTILL MTN VOD VODAFONE AIRTELTIGO].freeze

      def self.normalize(account_number:, settlement_bank:, market: nil)
        new(account_number: account_number, settlement_bank: settlement_bank, market: market).normalize
      end

      def self.mobile_money_bank?(settlement_bank)
        code = settlement_bank.to_s.upcase
        MOBILE_MONEY_BANK_CODES.include?(code) || code.include?("MPESA")
      end

      def initialize(account_number:, settlement_bank:, market: nil)
        @account_number = account_number
        @settlement_bank = settlement_bank
        @market = market
      end

      def normalize
        value = @account_number.to_s.strip.gsub(/\s+/, "")
        return value unless mobile_money?

        if value.start_with?("+254")
          value = "0#{value.delete_prefix("+254")}"
        elsif value.start_with?("254") && value.length == 12
          value = "0#{value.delete_prefix("254")}"
        elsif value.match?(/\A7\d{8}\z/)
          value = "0#{value}"
        end

        value
      end

      def mobile_money?
        self.class.mobile_money_bank?(@settlement_bank)
      end
    end
  end
end

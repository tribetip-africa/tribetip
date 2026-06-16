# frozen_string_literal: true

module Tribetip
  module Paystack
    class Market
      attr_reader :country_code, :name, :currency, :paystack_bank_country,
                  :stub_bank_name, :stub_settlement_bank, :stub_account_number,
                  :subaccount_supported, :mobile_money_supported

      MARKETS = {
        "NG" => {
          name: "Nigeria",
          currency: "NGN",
          paystack_bank_country: "nigeria",
          stub_bank_name: "Zenith Bank",
          stub_settlement_bank: "057",
          stub_account_number: "0000000000",
          subaccount_supported: true,
          mobile_money_supported: false
        },
        "GH" => {
          name: "Ghana",
          currency: "GHS",
          paystack_bank_country: "ghana",
          stub_bank_name: "MTN Mobile Money",
          stub_settlement_bank: "MTN",
          stub_account_number: "0000000000",
          subaccount_supported: true,
          mobile_money_supported: true
        },
        "KE" => {
          name: "Kenya",
          currency: "KES",
          paystack_bank_country: "kenya",
          stub_bank_name: "KCB Bank",
          stub_settlement_bank: "68",
          stub_account_number: "0000000000",
          subaccount_supported: true,
          mobile_money_supported: true
        },
        "ZA" => {
          name: "South Africa",
          currency: "ZAR",
          paystack_bank_country: "south africa",
          stub_bank_name: "ABSA Bank",
          stub_settlement_bank: "632005",
          stub_account_number: "0000000000",
          subaccount_supported: true,
          mobile_money_supported: false
        },
        "CI" => {
          name: "Côte d'Ivoire",
          currency: "XOF",
          paystack_bank_country: "cote d'ivoire",
          stub_bank_name: "Stub Bank",
          stub_settlement_bank: "CI001",
          stub_account_number: "0000000000",
          subaccount_supported: false,
          mobile_money_supported: false
        }
      }.freeze

      def self.find(country_code)
        code = country_code.to_s.upcase
        config = MARKETS[code]
        raise ArgumentError, "Unsupported Paystack market: #{country_code}" if config.blank?

        new(country_code: code, **config)
      end

      def self.for_tribe(tribe)
        find(tribe.country_code)
      end

      def self.supported_country_codes
        MARKETS.keys
      end

      def initialize(country_code:, name:, currency:, paystack_bank_country:,
                     stub_bank_name:, stub_settlement_bank:, stub_account_number:,
                     subaccount_supported:, mobile_money_supported:)
        @country_code = country_code
        @name = name
        @currency = currency
        @paystack_bank_country = paystack_bank_country
        @stub_bank_name = stub_bank_name
        @stub_settlement_bank = stub_settlement_bank
        @stub_account_number = stub_account_number
        @subaccount_supported = subaccount_supported
        @mobile_money_supported = mobile_money_supported
      end

      def subaccount_supported?
        subaccount_supported
      end

      def mobile_money_supported?
        mobile_money_supported
      end

      def currency_matches?(value)
        currency == value.to_s.upcase
      end

      def paystack_metadata_for(tribe)
        {
          tribe_id: tribe.id,
          username: tribe.username,
          subaccount_code: tribe.paystack_subaccount_code,
          country_code: country_code,
          currency: currency,
          paystack_bank_country: paystack_bank_country
        }.compact
      end

      def as_json(*)
        {
          country_code: country_code,
          name: name,
          currency: currency,
          paystack_bank_country: paystack_bank_country,
          subaccount_supported: subaccount_supported,
          mobile_money_supported: mobile_money_supported
        }
      end
    end
  end
end

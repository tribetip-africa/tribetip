# frozen_string_literal: true

module Tribetip
  module Paystack
    class SettlementRecord
      STATUSES = %w[pending processing success failed reversed].freeze

      attr_reader :id, :amount_cents, :currency, :status, :settled_at, :destination, :reference

      def self.from_transfer(row, tribe:)
        data = row.is_a?(Hash) ? row.with_indifferent_access : {}
        metadata = data[:metadata].is_a?(Hash) ? data[:metadata].with_indifferent_access : {}
        recipient = data[:recipient].is_a?(Hash) ? data[:recipient] : {}
        details = recipient["details"].is_a?(Hash) ? recipient["details"] : {}

        new(
          id: data[:transfer_code].presence || data[:id].to_s,
          amount_cents: data[:amount].to_i,
          currency: data[:currency].to_s.presence || tribe.currency,
          status: normalize_status(data[:status]),
          settled_at: parse_time(data[:createdAt] || data[:updatedAt]),
          destination: destination_label(details, tribe: tribe),
          reference: data[:reference].presence || data[:transfer_code]
        )
      end

      def self.from_stub_tip(tip, tribe:, destination:)
        net_cents = net_settlement_cents(tip.amount_cents)

        new(
          id: "settlement_#{tip.paystack_reference}",
          amount_cents: net_cents,
          currency: tip.currency,
          status: "success",
          settled_at: (tip.paid_at || tip.created_at) + 1.day,
          destination: destination,
          reference: tip.paystack_reference
        )
      end

      def self.net_settlement_cents(gross_cents)
        PlatformFee.net_cents(gross_cents)
      end

      def self.from_stored(settlement)
        new(
          id: settlement.paystack_transfer_code,
          amount_cents: settlement.amount_cents,
          currency: settlement.currency,
          status: settlement.status,
          settled_at: settlement.settled_at,
          destination: settlement.destination,
          reference: settlement.reference,
          source: settlement.metadata.is_a?(Hash) ? settlement.metadata["source"] : nil,
          updated_at: settlement.updated_at
        )
      end

      attr_reader :source, :updated_at

      def initialize(id:, amount_cents:, currency:, status:, settled_at:, destination:, reference:,
                     source: nil, updated_at: nil)
        @id = id
        @amount_cents = amount_cents
        @currency = currency
        @status = status
        @settled_at = settled_at
        @destination = destination
        @reference = reference
        @source = source
        @updated_at = updated_at
      end

      def as_json(*)
        {
          id: id,
          amount_cents: amount_cents,
          currency: currency,
          status: status,
          settled_at: settled_at&.iso8601,
          destination: destination,
          reference: reference,
          source: source,
          updated_at: updated_at&.iso8601
        }.compact
      end

      def self.normalize_status(value)
        status = value.to_s.downcase
        STATUSES.include?(status) ? status : "processing"
      end

      def self.parse_time(value)
        return if value.blank?

        Time.zone.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def self.destination_label(details, tribe:)
        account_number = details["account_number"].to_s
        bank_name = details["bank_name"].to_s.presence || tribe.paystack_market.stub_bank_name
        return bank_name if account_number.blank?

        masked = mask_account_number(account_number)
        [ bank_name, masked ].compact.join(" · ")
      end

      def self.mask_account_number(value)
        digits = value.to_s.gsub(/\s+/, "")
        return digits if digits.length <= 4

        "#{'•' * (digits.length - 4)}#{digits.last(4)}"
      end

      private_class_method :normalize_status, :parse_time, :destination_label
    end
  end
end

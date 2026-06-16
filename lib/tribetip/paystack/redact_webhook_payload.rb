# frozen_string_literal: true

module Tribetip
  module Paystack
    class RedactWebhookPayload
      REDACTED = "[REDACTED]"
      SENSITIVE_KEYS = %w[
        account_number
        authorization
        authorization_code
        bin
        brand
        card
        customer
        email
        exp_month
        exp_year
        last4
        mobile
        phone
        recipient
      ].freeze

      def self.call(payload)
        new(payload).call
      end

      def initialize(payload)
        @payload = payload
      end

      def call
        redact(@payload)
      end

      private

      def redact(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, nested), redacted|
            key = key.to_s
            redacted[key] = sensitive_key?(key) ? REDACTED : redact(nested)
          end
        when Array
          value.map { |nested| redact(nested) }
        else
          value
        end
      end

      def sensitive_key?(key)
        SENSITIVE_KEYS.include?(key.to_s.downcase)
      end
    end
  end
end

# frozen_string_literal: true

module Tribetip
  module Paystack
    module PayoutMode
      MODES = %w[auto manual both].freeze

      module_function

      def mode
        value = ENV.fetch("TRIBETIP_PAYOUT_MODE", "auto").to_s.downcase
        MODES.include?(value) ? value : "auto"
      end

      def manual?(configured = mode)
        configured.in?(%w[manual both])
      end

      def auto?(configured = mode)
        configured.in?(%w[auto both])
      end

      def effective_mode(configured: mode, transfers_supported:)
        case configured
        when "manual"
          transfers_supported ? "manual" : "auto"
        when "both"
          transfers_supported ? "both" : "auto"
        else
          "auto"
        end
      end

      def manual_enabled?(configured: mode, transfers_supported:)
        effective_mode(configured: configured, transfers_supported: transfers_supported).in?(%w[manual both])
      end

      def auto_active?(configured: mode, transfers_supported:)
        effective_mode(configured: configured, transfers_supported: transfers_supported).in?(%w[auto both])
      end

      def settlement_schedule(transfers_supported:)
        manual = manual_enabled?(transfers_supported: transfers_supported)
        auto = auto_active?(transfers_supported: transfers_supported)
        manual && !auto ? "MANUAL" : "AUTO"
      end

      def min_withdrawal_cents
        ENV.fetch("TRIBETIP_MIN_WITHDRAWAL_CENTS", "10000").to_i
      end

      def withdrawal_cooldown
        ENV.fetch("TRIBETIP_WITHDRAWAL_COOLDOWN_SECONDS", "300").to_i.seconds
      end
    end
  end
end

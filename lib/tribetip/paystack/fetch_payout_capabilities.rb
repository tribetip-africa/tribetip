# frozen_string_literal: true

module Tribetip
  module Paystack
    class FetchPayoutCapabilities
      CACHE_KEY = "paystack/platform/transfers_supported"
      CACHE_TTL = 7.days

      Capabilities = Struct.new(
        :configured_payout_mode,
        :effective_payout_mode,
        :transfers_supported,
        :business_tier,
        :manual_withdrawals_enabled,
        :auto_settlement_active,
        :blocker,
        keyword_init: true
      ) do
        def as_json(*)
          {
            configured_payout_mode: configured_payout_mode,
            effective_payout_mode: effective_payout_mode,
            transfers_supported: transfers_supported,
            business_tier: business_tier,
            manual_withdrawals_enabled: manual_withdrawals_enabled,
            auto_settlement_active: auto_settlement_active,
            withdraw_blocker: blocker
          }.compact
        end
      end

      def self.call(client: Client.new)
        new(client: client).call
      end

      def self.record_transfer_outcome!(message:, success:)
        if success
          write_transfers_supported!(true)
        elsif WithdrawalErrors.starter_business?(message)
          write_transfers_supported!(false)
        end
      end

      def self.write_transfers_supported!(value)
        SecureCache.write(CACHE_KEY, value ? "true" : "false", ttl: CACHE_TTL)
      end

      def self.clear!
        SecureCache.delete(CACHE_KEY)
      end

      def initialize(client: Client.new)
        @client = client
      end

      def call
        configured = PayoutMode.mode
        transfers = transfers_supported?
        effective = PayoutMode.effective_mode(
          configured: configured,
          transfers_supported: transfers
        )
        manual_enabled = PayoutMode.manual_enabled?(
          configured: configured,
          transfers_supported: transfers
        )
        auto_active = PayoutMode.auto_active?(
          configured: configured,
          transfers_supported: transfers
        )

        Capabilities.new(
          configured_payout_mode: configured,
          effective_payout_mode: effective,
          transfers_supported: transfers,
          business_tier: business_tier(transfers),
          manual_withdrawals_enabled: manual_enabled,
          auto_settlement_active: auto_active,
          blocker: capability_blocker(configured, manual_enabled, transfers)
        )
      end

      private

      def transfers_supported?
        explicit = ENV["TRIBETIP_PAYSTACK_TRANSFERS_ENABLED"].to_s.downcase
        return true if explicit == "true"
        return false if explicit == "false"

        return true if @client.stub_mode?

        cached = SecureCache.read(CACHE_KEY)
        return true if cached == "true"
        return false if cached == "false"

        tier = ENV.fetch("TRIBETIP_PAYSTACK_BUSINESS_TIER", "unknown").to_s.downcase
        tier != "starter"
      end

      def business_tier(transfers_supported)
        explicit = ENV["TRIBETIP_PAYSTACK_BUSINESS_TIER"].to_s.downcase
        return explicit if explicit.in?(%w[starter registered unknown])

        return "starter" unless transfers_supported

        "unknown"
      end

      def capability_blocker(configured, manual_enabled, transfers_supported)
        return nil if manual_enabled

        if configured.in?(%w[manual both]) && !transfers_supported
          "Manual withdrawals require Paystack Registered Business with Transfers enabled. " \
            "Tips settle automatically on Paystack's schedule until then."
        end
      end
    end
  end
end

# frozen_string_literal: true

module Tribetip
  module Paystack
    class FetchPayoutStatus
      CACHE_TTL = 5.minutes

      Status = Struct.new(
        :subaccount_verified,
        :settlement_bank,
        :account_number,
        :account_name,
        :settlement_schedule,
        :settlement_schedule_label,
        :pending_settlement_cents,
        :available_to_settle_cents,
        :total_transactions,
        :total_volume_cents,
        :currency,
        :can_publish,
        :publish_blocker,
        :refreshed_at,
        keyword_init: true
      ) do
        def as_json(*)
          {
            subaccount_verified: subaccount_verified,
            settlement_bank: settlement_bank,
            account_number: account_number,
            account_name: account_name,
            settlement_schedule: settlement_schedule,
            settlement_schedule_label: settlement_schedule_label,
            pending_settlement_cents: pending_settlement_cents,
            available_to_settle_cents: available_to_settle_cents,
            total_transactions: total_transactions,
            total_volume_cents: total_volume_cents,
            currency: currency,
            can_publish: can_publish,
            publish_blocker: publish_blocker,
            refreshed_at: refreshed_at
          }.compact
        end
      end

      def self.call(tribe, refresh: false)
        new(tribe).call(refresh: refresh)
      end

      def self.cache_key_for(tribe)
        "paystack_payout_status/#{tribe.id}/#{tribe.paystack_subaccount_code}"
      end

      def self.invalidate_cache(tribe)
        Tribetip::SecureCache.delete(cache_key_for(tribe))
      end

      def initialize(tribe)
        @tribe = tribe
        @client = Client.new
        @market = Market.for_tribe(tribe)
      end

      def call(refresh: false)
        self.class.invalidate_cache(@tribe) if refresh

        Tribetip::SecureCache.fetch(cache_key, scope: :public, ttl: CACHE_TTL) do
          build_status.as_json
        end.then { |payload| Status.new(**payload.symbolize_keys) }
      end

      private

      def cache_key
        self.class.cache_key_for(@tribe)
      end

      def build_status
        unless @market.subaccount_supported?
          return Status.new(
            subaccount_verified: false,
            can_publish: false,
            publish_blocker: "Payout setup is not available in your market yet.",
            currency: @market.currency,
            available_to_settle_cents: 0,
            settlement_schedule_label: settlement_schedule_label(nil),
            refreshed_at: Time.current.iso8601
          )
        end

        unless @tribe.paystack_subaccount_code.present?
          return Status.new(
            subaccount_verified: false,
            can_publish: false,
            publish_blocker: "Link your payout account to continue.",
            currency: @market.currency,
            available_to_settle_cents: 0,
            settlement_schedule_label: settlement_schedule_label(nil),
            refreshed_at: Time.current.iso8601
          )
        end

        if @client.stub_mode?
          return stub_status
        end

        subaccount = @client.fetch_subaccount(@tribe.paystack_subaccount_code)
        totals = @client.fetch_transaction_totals(subaccount: @tribe.paystack_subaccount_code)
        data = subaccount.data.is_a?(Hash) ? subaccount.data : {}
        totals_data = totals.data.is_a?(Hash) ? totals.data : {}

        verified = data["is_verified"] == true
        pending = totals_data["pending_transfers"].to_i
        currency = data["currency"].presence || @market.currency
        schedule = data["settlement_schedule"]

        status_for(
          verified: verified,
          settlement_bank: data["settlement_bank"],
          account_number: data["account_number"],
          account_name: data["account_name"],
          settlement_schedule: schedule,
          pending_cents: pending,
          total_transactions: totals_data["total_transactions"].to_i,
          total_volume_cents: totals_data["total_volume"].to_i,
          currency: currency
        )
      end

      def stub_status
        ready = @tribe.paystack_subaccount_ready?
        verified = ready
        capabilities = FetchPayoutCapabilities.call(client: @client)

        status_for(
          verified: verified,
          settlement_bank: @market.stub_settlement_bank,
          account_number: @market.stub_account_number,
          settlement_schedule: PayoutMode.settlement_schedule(
            transfers_supported: capabilities.transfers_supported
          ),
          pending_cents: stub_pending_settlement_cents,
          currency: @market.currency
        )
      end

      def status_for(verified:, settlement_bank:, account_number:, settlement_schedule:, pending_cents:, currency:,
                     account_name: nil, total_transactions: nil, total_volume_cents: nil)
        Status.new(
          subaccount_verified: verified,
          settlement_bank: settlement_bank,
          account_number: mask_account_number(account_number),
          account_name: account_name,
          settlement_schedule: settlement_schedule,
          settlement_schedule_label: settlement_schedule_label(settlement_schedule),
          pending_settlement_cents: pending_cents.positive? ? pending_cents : nil,
          available_to_settle_cents: pending_cents,
          total_transactions: total_transactions,
          total_volume_cents: total_volume_cents,
          currency: currency,
          can_publish: publish_allowed?(verified),
          publish_blocker: publish_blocker_message(verified),
          refreshed_at: Time.current.iso8601
        )
      end

      def stub_pending_settlement_cents
        AvailableBalance.call(@tribe).amount_cents
      end

      def settlement_schedule_label(schedule)
        case schedule.to_s.upcase
        when "AUTO"
          "Automatic — Paystack settles to your linked payout account"
        when "MANUAL"
          "Manual — withdraw to your linked payout account when you choose"
        else
          schedule.presence || "Automatic — Paystack settles to your linked payout account"
        end
      end

      def publish_allowed?(verified)
        @tribe.account_status == "active" &&
          @tribe.paystack_onboarding_complete? &&
          verified
      end

      def publish_blocker_message(verified)
        return nil if publish_allowed?(verified)
        return "Your account must be active before publishing." unless @tribe.account_status == "active"
        return "Complete payout setup before publishing." unless @tribe.paystack_onboarding_complete?
        return "Paystack is still verifying your payout account. Check back soon or refresh status below." unless verified

        "Publishing is not available yet."
      end

      def mask_account_number(value)
        digits = value.to_s.gsub(/\s+/, "")
        return nil if digits.blank?

        return digits if digits.length <= 4

        "#{'•' * (digits.length - 4)}#{digits.last(4)}"
      end
    end
  end
end

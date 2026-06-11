# frozen_string_literal: true

module Tribetip
  module Paystack
    class BuildWithdrawalStatus
      Status = Struct.new(
        :payout_mode,
        :configured_payout_mode,
        :effective_payout_mode,
        :transfers_supported,
        :business_tier,
        :auto_settlement_active,
        :available_to_withdraw_cents,
        :min_withdrawal_cents,
        :can_withdraw,
        :withdraw_blocker,
        :destination,
        :currency,
        :pending_withdrawal,
        :cooldown_ends_at,
        keyword_init: true
      ) do
        def as_json(*)
          {
            payout_mode: effective_payout_mode || payout_mode,
            configured_payout_mode: configured_payout_mode,
            effective_payout_mode: effective_payout_mode,
            transfers_supported: transfers_supported,
            business_tier: business_tier,
            auto_settlement_active: auto_settlement_active,
            available_to_withdraw_cents: available_to_withdraw_cents,
            min_withdrawal_cents: min_withdrawal_cents,
            can_withdraw: can_withdraw,
            withdraw_blocker: withdraw_blocker,
            destination: destination,
            currency: currency,
            pending_withdrawal: pending_withdrawal,
            cooldown_ends_at: cooldown_ends_at&.iso8601
          }.compact
        end
      end

      def self.call(tribe, refresh: false)
        new(tribe).call(refresh: refresh)
      end

      def initialize(tribe)
        @tribe = tribe
      end

      def call(refresh: false)
        capabilities = FetchPayoutCapabilities.call
        balance = AvailableBalance.call(@tribe, refresh: refresh)
        payout = FetchPayoutStatus.call(@tribe, refresh: refresh)
        pending = pending_withdrawal
        cooldown_ends_at = cooldown_ends_at_for
        blocker = withdraw_blocker(balance.amount_cents, pending, cooldown_ends_at, payout, capabilities) ||
                  capabilities.blocker

        Status.new(
          payout_mode: capabilities.effective_payout_mode,
          configured_payout_mode: capabilities.configured_payout_mode,
          effective_payout_mode: capabilities.effective_payout_mode,
          transfers_supported: capabilities.transfers_supported,
          business_tier: capabilities.business_tier,
          auto_settlement_active: capabilities.auto_settlement_active,
          available_to_withdraw_cents: balance.amount_cents,
          min_withdrawal_cents: PayoutMode.min_withdrawal_cents,
          can_withdraw: blocker.blank? && capabilities.manual_withdrawals_enabled,
          withdraw_blocker: blocker,
          destination: destination_label(payout),
          currency: balance.currency,
          pending_withdrawal: pending&.to_settlement_record&.as_json,
          cooldown_ends_at: blocker.present? ? cooldown_ends_at : nil
        )
      end

      private

      def pending_withdrawal
        @tribe.paystack_settlements
              .where(status: %w[pending processing])
              .where("metadata->>'source' = ?", "manual_withdrawal")
              .order(created_at: :desc)
              .first
      end

      def cooldown_ends_at_for
        last_withdrawal = @tribe.paystack_settlements
                                .where("metadata->>'source' = ?", "manual_withdrawal")
                                .order(created_at: :desc)
                                .first
        return if last_withdrawal.blank?

        ends_at = last_withdrawal.created_at + PayoutMode.withdrawal_cooldown
        ends_at if ends_at > Time.current
      end

      def withdraw_blocker(amount_cents, pending, cooldown_ends_at, payout, capabilities)
        unless capabilities.manual_withdrawals_enabled
          return capabilities.blocker || "Manual withdrawals are not enabled."
        end
        return "Complete payout setup before withdrawing." unless @tribe.paystack_onboarding_complete?
        return "Paystack is still verifying your payout account." unless payout.subaccount_verified
        return "A withdrawal is already processing." if pending.present?
        return "Please wait before requesting another withdrawal." if cooldown_ends_at.present?
        return "No funds available to withdraw yet." if amount_cents.to_i <= 0
        if amount_cents.to_i < PayoutMode.min_withdrawal_cents
          return "Minimum withdrawal is #{PayoutMode.min_withdrawal_cents / 100.0} #{payout.currency}."
        end

        nil
      end

      def destination_label(payout)
        bank = payout.settlement_bank
        account = payout.account_number
        return nil if bank.blank? && account.blank?

        [ bank, account ].compact.join(" · ")
      end
    end
  end
end

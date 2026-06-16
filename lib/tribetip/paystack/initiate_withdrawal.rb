# frozen_string_literal: true

module Tribetip
  module Paystack
    class InitiateWithdrawal
      Result = Struct.new(:success?, :settlement, :message, :status, keyword_init: true)

      def self.call(tribe, actor_id: nil)
        new(tribe, actor_id: actor_id).call
      end

      def initialize(tribe, actor_id: nil)
        @tribe = tribe
        @actor_id = actor_id
        @client = Client.new
        @market = Market.for_tribe(tribe)
      end

      def call
        capabilities = FetchPayoutCapabilities.call
        return failure(capabilities.blocker || "Manual withdrawals are not enabled.") unless capabilities.manual_withdrawals_enabled

        @tribe.with_lock do
          @tribe.reload
          status = BuildWithdrawalStatus.call(@tribe, refresh: true)
          return failure(status.withdraw_blocker || "Withdrawal is not available right now.") unless status.can_withdraw

          amount_cents = status.available_to_withdraw_cents
          reference = "wd_#{SecureRandom.hex(12)}"
          payout = FetchPayoutStatus.call(@tribe, refresh: true)
          destination = [ payout.settlement_bank, payout.account_number ].compact.join(" · ")

          transfer = @client.initiate_subaccount_withdrawal(
            subaccount: @tribe.paystack_subaccount_code,
            amount_cents: amount_cents,
            currency: status.currency,
            reference: reference,
            reason: "TribeTip creator withdrawal",
            metadata: {
              tribe_id: @tribe.id,
              username: @tribe.username,
              subaccount_code: @tribe.paystack_subaccount_code,
              actor_id: @actor_id
            }.compact
          )

          unless transfer.success?
            FetchPayoutCapabilities.record_transfer_outcome!(message: transfer.message, success: false)

            if WithdrawalErrors.starter_business?(transfer.message)
              Tribetip::Audit::PaymentLogger.log(
                event: "withdrawal_blocked",
                tribe_id: @tribe.id,
                metadata: {
                  reason: "paystack_starter_business",
                  paystack_message: transfer.message
                }
              )
            end

            return failure(WithdrawalErrors.friendly_message(transfer.message))
          end

          FetchPayoutCapabilities.record_transfer_outcome!(message: transfer.message, success: true)

          settlement = PaystackSettlement.create!(
            tribe: @tribe,
            paystack_transfer_code: transfer.transfer_code,
            amount_cents: amount_cents,
            currency: status.currency,
            status: transfer.status,
            settled_at: transfer.status == "success" ? Time.current : nil,
            destination: destination.presence,
            reference: reference,
            metadata: {
              source: "manual_withdrawal",
              requested_at: Time.current.iso8601,
              actor_id: @actor_id
            }.compact
          )

          if settlement.status != "success" && (@client.stub_mode? || @client.simulate_transfers?)
            complete_stub_withdrawal!(settlement)
          end

          FetchPayoutStatus.invalidate_cache(@tribe)
          ListSettlements.invalidate_cache(@tribe)

          Tribetip::Audit::PaymentLogger.log(
            event: "withdrawal_requested",
            tribe_id: @tribe.id,
            metadata: {
              paystack_transfer_code: settlement.paystack_transfer_code,
              amount_cents: settlement.amount_cents,
              currency: settlement.currency
            }
          )

          Result.new(
            success?: true,
            settlement: settlement,
            message: "Withdrawal initiated.",
            status: BuildWithdrawalStatus.call(@tribe, refresh: true)
          )
        end
      rescue ActiveRecord::RecordInvalid => error
        failure(error.record.errors.full_messages.to_sentence)
      end

      private

      def complete_stub_withdrawal!(settlement)
        settlement.update!(status: "success", settled_at: Time.current)
        ::Paystack::NotifySettlementJob.perform_later(settlement.id, "transfer.success")
      end

      def failure(message)
        Result.new(success?: false, message: message)
      end
    end
  end
end

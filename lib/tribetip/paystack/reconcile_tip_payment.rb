# frozen_string_literal: true

module Tribetip
  module Paystack
    class ReconcileTipPayment
      Result = Struct.new(:success?, :tip, :message, keyword_init: true)

      def self.call(
        tip,
        paid_via: :reconcile,
        paystack_event: nil,
        request_context: nil,
        actor_id: nil
      )
        new(
          tip,
          paid_via: paid_via,
          paystack_event: paystack_event,
          request_context: request_context,
          actor_id: actor_id
        ).call
      end

      def initialize(tip, paid_via: :reconcile, paystack_event: nil, request_context: nil, actor_id: nil)
        @tip = tip
        @paid_via = paid_via
        @paystack_event = paystack_event
        @request_context = request_context
        @actor_id = actor_id
        @client = Client.new
      end

      def call
        return success(@tip) if @tip.paid?

        verification = @client.verify_transaction(@tip.paystack_reference)
        record_reconcile_attempt(verification)

        unless verification.success?
          store_verification_snapshot(verification, success: false, message: verification.message)
          return failure(verification.message || "Unable to verify Paystack transaction.")
        end

        case verification.status
        when "success"
          verify_subaccount!(verification.subaccount_code)
          mark_paid!(verification)
          success(@tip.reload)
        when "failed", "abandoned", "reversed"
          mark_failed!(verification, "Paystack reported payment status: #{verification.status}.")
          failure("Paystack reported payment status: #{verification.status}.")
        else
          store_verification_snapshot(
            verification,
            success: false,
            message: "Paystack payment is still #{verification.status || 'pending'}."
          )
          failure("Paystack payment is still #{verification.status || 'pending'}.")
        end
      end

      private

      def source
        @paid_via.to_s
      end

      def verify_subaccount!(subaccount_code)
        expected = @tip.tribe.paystack_subaccount_code.to_s.strip
        return if expected.blank?

        actual = subaccount_code.to_s.strip
        return if actual.blank?

        return if actual.casecmp?(expected)

        raise Tribetip::Errors::BadRequest.new(
          "Paystack subaccount mismatch for this tip.",
          details: { expected: expected, actual: actual }
        )
      end

      def mark_paid!(verification)
        snapshot = store_verification_snapshot(verification, success: true)

        @tip.with_lock do
          @tip.reload
          return unless @tip.pending?

          @tip.mark_paid!(
            via: @paid_via,
            paystack_event: @paystack_event,
            verification: snapshot,
            source: source,
            actor_id: @actor_id,
            request_context: @request_context
          )
        end

        Tribetip::Audit::PaymentLogger.log(
          event: "tip_reconciled_paid",
          tip_id: @tip.id,
          paystack_reference: @tip.paystack_reference,
          paid_via: @paid_via,
          paystack_event_id: @paystack_event&.id
        )
      end

      def mark_failed!(verification, message)
        snapshot = store_verification_snapshot(verification, success: false, message: message)

        @tip.with_lock do
          @tip.reload
          return unless @tip.pending?

          @tip.mark_failed!(
            reason: message,
            paystack_event: @paystack_event,
            verification: snapshot,
            source: source,
            actor_id: @actor_id,
            request_context: @request_context
          )
        end
      end

      def record_reconcile_attempt(verification)
        Tribetip::Audit::RecordTipEvent.call(
          tip: @tip,
          action: "reconcile_attempted",
          from_status: @tip.status,
          to_status: @tip.status,
          source: source,
          actor_id: @actor_id,
          paystack_event: @paystack_event,
          verification: verification_snapshot(verification, success: verification.success?),
          request_context: @request_context,
          metadata: { paystack_status: verification.status }
        )
      end

      def store_verification_snapshot(verification, success:, message: nil)
        Tribetip::Audit::StoreVerificationSnapshot.call(
          tip: @tip,
          source: source,
          verification: verification,
          success: success,
          message: message,
          paystack_event: @paystack_event
        )
      end

      def verification_snapshot(verification, success:, message: nil)
        {
          "status" => verification.status,
          "subaccount_code" => verification.subaccount_code,
          "success" => success,
          "message" => message
        }.compact
      end

      def success(tip)
        Result.new(success?: true, tip: tip)
      end

      def failure(message)
        Result.new(success?: false, message: message)
      end
    end
  end
end

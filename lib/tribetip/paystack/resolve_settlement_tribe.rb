# frozen_string_literal: true

module Tribetip
  module Paystack
    class ResolveSettlementTribe
      Result = Struct.new(:tribe, :rejected_reason, keyword_init: true) do
        def accepted?
          tribe.present?
        end
      end

      def self.call(payload)
        new(payload).call
      end

      def initialize(payload)
        @payload = payload.is_a?(Hash) ? payload.with_indifferent_access : {}
        @metadata = extract_metadata
      end

      def call
        subaccount_code = extract_subaccount_code
        tribe_by_subaccount = find_tribe_by_subaccount(subaccount_code)
        tribe_by_id = find_tribe_by_id(@metadata[:tribe_id])

        if tribe_by_subaccount && tribe_by_id && tribe_by_subaccount.id != tribe_by_id.id
          return reject("tribe_id_subaccount_conflict", tribe_by_subaccount)
        end

        tribe = tribe_by_subaccount || tribe_by_id
        return reject("tribe_not_found") unless tribe

        if subaccount_code.present? && !subaccount_matches_tribe?(subaccount_code, tribe)
          return reject("subaccount_mismatch", tribe)
        end

        if @metadata[:tribe_id].present? && tribe.id.to_s != @metadata[:tribe_id].to_s
          return reject("tribe_id_mismatch", tribe)
        end

        Result.new(tribe: tribe)
      end

      private

      def extract_metadata
        metadata = @payload[:metadata]
        metadata.is_a?(Hash) ? metadata.with_indifferent_access : {}.with_indifferent_access
      end

      def extract_subaccount_code
        @metadata[:subaccount_code].to_s.presence ||
          subaccount_code_from_reason(@payload[:reason])
      end

      def subaccount_code_from_reason(reason)
        code = reason.to_s[/ACCT_[a-zA-Z0-9_]+/]
        code.presence
      end

      def find_tribe_by_subaccount(subaccount_code)
        return if subaccount_code.blank?

        Tribe.find_by(paystack_subaccount_code: subaccount_code)
      end

      def find_tribe_by_id(tribe_id)
        return if tribe_id.blank?

        Tribe.find_by(id: tribe_id)
      end

      def subaccount_matches_tribe?(subaccount_code, tribe)
        expected = tribe.paystack_subaccount_code.to_s.strip
        return true if expected.blank?

        subaccount_code.to_s.strip.casecmp?(expected)
      end

      def reject(reason, tribe = nil)
        metadata = {
          reason: reason,
          metadata_tribe_id: @metadata[:tribe_id],
          metadata_subaccount_code: @metadata[:subaccount_code],
          metadata_username: @metadata[:username],
          transfer_code: @payload[:transfer_code] || @payload[:id],
          reference: @payload[:reference]
        }

        Tribetip::Audit::PaymentLogger.log(
          event: "settlement_tribe_rejected",
          tribe_id: tribe&.id,
          metadata: metadata
        )

        Tribetip::Audit::RecordPaymentAlert.call(
          kind: "settlement_tribe_rejected",
          title: "Settlement webhook rejected",
          body: settlement_rejection_message(reason, metadata),
          metadata: metadata,
          severity: "warning"
        )

        Result.new(tribe: nil, rejected_reason: reason)
      end

      def settlement_rejection_message(reason, metadata)
        transfer_code = metadata[:transfer_code].presence || "unknown transfer"
        "Rejected #{transfer_code}: #{reason.tr('_', ' ')}."
      end
    end
  end
end

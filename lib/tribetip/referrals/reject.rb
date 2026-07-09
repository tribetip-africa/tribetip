# frozen_string_literal: true

module Tribetip
  module Referrals
    class Reject
      def self.call(referral, reason:, actor_id: nil, metadata: {})
        new(referral, reason: reason, actor_id: actor_id, metadata: metadata).call
      end

      def initialize(referral, reason:, actor_id: nil, metadata: {})
        @referral = referral
        @reason = reason.to_s.strip
        @actor_id = actor_id
        @metadata = metadata
      end

      def call
        return false if @referral.rejected?
        return false if @referral.rewarded?

        @referral.update!(
          status: "rejected",
          metadata: @referral.metadata.merge(
            "rejected_at" => Time.current.iso8601,
            "rejected_reason" => @reason,
            "rejected_by" => @actor_id,
            **@metadata.stringify_keys
          ).compact
        )

        true
      end
    end
  end
end

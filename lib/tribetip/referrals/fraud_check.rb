# frozen_string_literal: true

module Tribetip
  module Referrals
    module FraudCheck
      REASONS = %w[
        same_ip_signup
        referrer_at_capacity
        referrer_ineligible
        referrer_suspended
      ].freeze

      module_function

      def attach_blocked?(referrer:, signup_ip:)
        attach_block_reason(referrer: referrer, signup_ip: signup_ip).present?
      end

      def attach_block_reason(referrer:, signup_ip:)
        return "referrer_ineligible" unless Referrals.eligible_referrer?(referrer)
        return "referrer_at_capacity" if referrer_at_capacity?(referrer)
        return "same_ip_signup" if same_ip_signup?(referrer, signup_ip)

        nil
      end

      def qualification_block_reason(referral)
        referrer = referral.referrer
        return "referrer_suspended" if referrer.suspended?
        return "referrer_ineligible" unless Referrals.eligible_referrer?(referrer)
        return "same_ip_signup" if same_ip_signup?(
          referrer,
          referral.metadata["signup_ip"]
        )

        nil
      end

      def reward_block_reason(referral)
        qualification_block_reason(referral)
      end

      def referrer_at_capacity?(referrer)
        return false if max_referrals_per_referrer <= 0

        active_referral_count(referrer) >= max_referrals_per_referrer
      end

      def active_referral_count(referrer)
        referrer.referrals_given.where.not(status: "rejected").count
      end

      def same_ip_signup?(referrer, signup_ip)
        return false unless Config.block_same_ip_referrals?

        ip = signup_ip.to_s.strip
        return false if ip.blank?

        referrer_ips(referrer).include?(ip)
      end

      def referrer_ips(referrer)
        [ referrer.current_sign_in_ip, referrer.last_sign_in_ip ].compact.map(&:to_s).uniq
      end

      def max_referrals_per_referrer
        Config.max_referrals_per_referrer
      end
    end
  end
end

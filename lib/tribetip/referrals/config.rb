# frozen_string_literal: true

module Tribetip
  module Referrals
    module Config
      DEFAULT_REFERRER_BONUS_CENTS = {
        "KES" => 50_000,
        "NGN" => 5_000_00,
        "GHS" => 50_00,
        "ZAR" => 100_00,
        "XOF" => 5_000_00,
        "USD" => 5_00
      }.freeze

      DEFAULT_REFERRED_FEE_CREDIT_CENTS = {
        "KES" => 1_000_000,
        "NGN" => 100_000_00,
        "GHS" => 1_000_00,
        "ZAR" => 2_000_00,
        "XOF" => 100_000_00,
        "USD" => 100_00
      }.freeze

      module_function

      def enabled?
        ActiveModel::Type::Boolean.new.cast(ENV.fetch("TRIBETIP_REFERRALS_ENABLED", "true"))
      end

      def min_qualification_tip_cents(currency)
        ENV.fetch("TRIBETIP_REFERRAL_MIN_QUALIFICATION_TIP_CENTS_#{currency.upcase}", "10000").to_i
      rescue KeyError
        ENV.fetch("TRIBETIP_REFERRAL_MIN_QUALIFICATION_TIP_CENTS", "10000").to_i
      end

      def referrer_bonus_cents(currency)
        ENV.fetch("TRIBETIP_REFERRAL_BONUS_CENTS_#{currency.upcase}", default_referrer_bonus(currency)).to_i
      rescue KeyError
        default_referrer_bonus(currency)
      end

      def referred_fee_credit_cents(currency)
        ENV.fetch("TRIBETIP_REFERRED_FEE_CREDIT_CENTS_#{currency.upcase}", default_referred_fee_credit(currency)).to_i
      rescue KeyError
        default_referred_fee_credit(currency)
      end

      def max_referrals_per_referrer
        ENV.fetch("TRIBETIP_REFERRAL_MAX_PER_REFERRER", "50").to_i
      end

      def block_same_ip_referrals?
        ActiveModel::Type::Boolean.new.cast(
          ENV.fetch("TRIBETIP_REFERRAL_BLOCK_SAME_IP", "true")
        )
      end

      def invite_ttl_days
        ENV.fetch("TRIBETIP_REFERRAL_INVITE_TTL_DAYS", "30").to_i
      end

      def default_referrer_bonus(currency)
        DEFAULT_REFERRER_BONUS_CENTS.fetch(currency.to_s.upcase, 0)
      end

      def default_referred_fee_credit(currency)
        DEFAULT_REFERRED_FEE_CREDIT_CENTS.fetch(currency.to_s.upcase, 0)
      end
    end
  end
end

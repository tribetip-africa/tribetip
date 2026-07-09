# frozen_string_literal: true

module Tribetip
  module Referrals
    class AttachOnSignup
      def self.call(referred:, referral_code:, signup_ip: nil)
        new(referred: referred, referral_code: referral_code, signup_ip: signup_ip).call
      end

      def initialize(referred:, referral_code:, signup_ip: nil)
        @referred = referred
        @referral_code = Referrals.normalize_input(referral_code)
        @signup_ip = signup_ip.to_s.strip.presence
      end

      def call
        return if @referral_code.blank?
        return if @referred.referred_by_id.present?

        resolved = ResolveReferral.call(@referral_code)
        return unless resolved

        referrer = resolved.referrer
        return if referrer.id == @referred.id
        return if circular_referral?(referrer)
        return if FraudCheck.attach_blocked?(referrer: referrer, signup_ip: @signup_ip)

        ActiveRecord::Base.transaction do
          @referred.update!(referred_by_id: referrer.id)
          Referral.create!(
            referrer: referrer,
            referred: @referred,
            referral_code_used: resolved.code,
            status: "pending",
            metadata: {
              attached_at: Time.current.iso8601,
              signup_ip: @signup_ip,
              referral_source: resolved.source,
              referral_invite_id: resolved.invite&.id
            }.compact
          )
        end

        true
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        false
      end

      private

      def circular_referral?(referrer)
        referrer.referred_by_id == @referred.id
      end
    end
  end
end

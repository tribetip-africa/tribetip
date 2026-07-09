# frozen_string_literal: true

module Tribetip
  module Referrals
    module Invites
      TOKEN_BYTES = 16
      TOKEN_PATTERN = /\A[A-Za-z0-9_-]{20,48}\z/

      module_function

      def valid_token_format?(value)
        value.to_s.match?(TOKEN_PATTERN)
      end

      def ensure_active!(referrer)
        return unless referrer.referrals_enabled?

        invite = referrer.referral_invites.active.not_expired.order(created_at: :desc).first
        return invite if invite

        create!(referrer)
      end

      def rotate!(referrer)
        return unless referrer.referrals_enabled?

        referrer.referral_invites.active.find_each(&:revoke!)
        create!(referrer)
      end

      def revoke_all!(referrer)
        referrer.referral_invites.active.find_each(&:revoke!)
      end

      def resolve(code)
        return if code.blank?
        return unless valid_token_format?(code)

        invite = ReferralInvite.active.not_expired.find_by(code: code)
        return unless invite

        referrer = invite.referrer
        return unless Referrals.eligible_referrer?(referrer)

        invite
      end

      def signup_path(code)
        "/sign-up?ref=#{CGI.escape(code.to_s)}"
      end

      def signup_url(code)
        "#{Tribetip::Platform.app_url}#{signup_path(code)}"
      end

      def payload_for(invite)
        {
          code: invite.code,
          path: signup_path(invite.code),
          url: signup_url(invite.code),
          expires_at: invite.expires_at.iso8601,
          kind: "invite"
        }
      end

      def create!(referrer)
        return unless referrer.referrals_enabled?

        referrer.referral_invites.create!(
          code: generate_unique_code,
          expires_at: Config.invite_ttl_days.days.from_now
        )
      end

      def generate_unique_code
        loop do
          candidate = SecureRandom.urlsafe_base64(TOKEN_BYTES).tr("=", "")
          break candidate unless ReferralInvite.exists?(code: candidate)
        end
      end
    end
  end
end

# frozen_string_literal: true

module Tribetip
  module EarlyAccess
    module Invites
      TOKEN_BYTES = 16
      TOKEN_PATTERN = /\A[A-Za-z0-9_-]{20,48}\z/
      EMAIL_PATTERN = URI::MailTo::EMAIL_REGEXP

      module_function

      def valid_token_format?(value)
        value.to_s.match?(TOKEN_PATTERN)
      end

      def create!(email:, expires_in_days: nil)
        normalized = normalize_email(email)
        raise ArgumentError, "Email is required" if normalized.blank?
        raise ArgumentError, "Email is invalid" unless normalized.match?(EMAIL_PATTERN)

        ttl_days = (expires_in_days.presence || Config.invite_ttl_days).to_i
        ttl_days = Config.invite_ttl_days if ttl_days <= 0

        EarlyAccessInvite.create!(
          email: normalized,
          token: generate_unique_token,
          expires_at: ttl_days.days.from_now
        )
      end

      def resolve(token)
        return unless valid_token_format?(token)

        invite = EarlyAccessInvite.find_by(token: token.to_s)
        return unless invite&.available?

        invite
      end

      def burn!(invite, tribe:)
        invite.burn!(tribe: tribe)
      end

      def revoke!(invite)
        invite.revoke!
      end

      def path_for(token)
        "/early-access/#{CGI.escape(token.to_s)}"
      end

      def url_for(token)
        "#{Tribetip::Platform.app_url}#{path_for(token)}"
      end

      def payload_for(invite)
        {
          id: invite.id,
          email: invite.email,
          token: invite.token,
          path: path_for(invite.token),
          url: url_for(invite.token),
          expires_at: invite.expires_at.iso8601,
          used_at: invite.used_at&.iso8601,
          revoked_at: invite.revoked_at&.iso8601,
          available: invite.available?
        }
      end

      def normalize_email(email)
        email.to_s.strip.downcase
      end

      def generate_unique_token
        loop do
          candidate = SecureRandom.urlsafe_base64(TOKEN_BYTES).tr("=", "")
          break candidate unless EarlyAccessInvite.exists?(token: candidate)
        end
      end
    end
  end
end

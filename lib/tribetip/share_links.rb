# frozen_string_literal: true

module Tribetip
  module ShareLinks
    TOKEN_BYTES = 24
    TOKEN_PATTERN = /\A[A-Za-z0-9_-]{20,48}\z/

    class << self
      def valid_token_format?(value)
        value.to_s.match?(TOKEN_PATTERN)
      end

      def ensure_token!(tribe)
        return tribe.tip_share_token if tribe.tip_share_token.present?

        tribe.update!(tip_share_token: generate_unique_token)
        tribe.tip_share_token
      end

      def rotate!(tribe)
        previous = tribe.tip_share_token
        tribe.update!(tip_share_token: generate_unique_token)
        if previous.present?
          mark_revoked!(previous)
          purge_share_cache!(previous)
        end
        tribe.tip_share_token
      end

      def resolve_profile(token)
        return if token.blank?
        return unless valid_token_format?(token)
        return if revoked?(token)

        tribe = Tribe.find_by(tip_share_token: token)
        return unless tribe
        return unless shareable?(tribe)

        tribe
      end

      def shareable?(tribe)
        tribe.creator? &&
          tribe.is_profile_public? &&
          tribe.account_status == "active" &&
          !tribe.suspended?
      end

      def cache_key_for(token)
        "share_profile/#{Digest::SHA256.hexdigest(token.to_s)}"
      end

      def purge_share_cache!(token)
        return if token.blank?

        Tribetip::SecureCache.delete(cache_key_for(token), scope: :public)
      end

      def mark_revoked!(token)
        return if token.blank?

        Tribetip::SecureCache.write(
          revoked_cache_key_for(token),
          true,
          scope: :public,
          ttl: 10.years
        )
      end

      def revoked?(token)
        return false if token.blank?

        Tribetip::SecureCache.read(revoked_cache_key_for(token), scope: :public) == true
      end

      def revoked_cache_key_for(token)
        "share_revoked/#{Digest::SHA256.hexdigest(token.to_s)}"
      end

      private

      def generate_unique_token
        loop do
          candidate = SecureRandom.urlsafe_base64(TOKEN_BYTES).tr("=", "")
          break candidate unless Tribe.exists?(tip_share_token: candidate)
        end
      end
    end
  end
end

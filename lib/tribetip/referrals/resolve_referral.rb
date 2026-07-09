# frozen_string_literal: true

module Tribetip
  module Referrals
    ResolvedReferral = Struct.new(:referrer, :code, :invite, :source, keyword_init: true)

    class ResolveReferral
      def self.call(code)
        new(code).call
      end

      def initialize(code)
        @raw = code.to_s.strip
      end

      def call
        return if @raw.blank?

        if Invites.valid_token_format?(@raw)
          resolve_invite
        elsif Referrals.valid_username_code?(@raw)
          resolve_username
        end
      end

      private

      def resolve_invite
        invite = Invites.resolve(@raw)
        return unless invite

        ResolvedReferral.new(
          referrer: invite.referrer,
          code: invite.code,
          invite: invite,
          source: "invite"
        )
      end

      def resolve_username
        username = Referrals.normalize_username(@raw)
        tribe = Tribe.find_by(username: username)
        return unless tribe
        return unless Referrals.eligible_referrer?(tribe)

        ResolvedReferral.new(
          referrer: tribe,
          code: username,
          invite: nil,
          source: "username"
        )
      end
    end
  end
end

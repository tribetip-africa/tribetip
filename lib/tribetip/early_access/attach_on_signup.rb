# frozen_string_literal: true

module Tribetip
  module EarlyAccess
    module AttachOnSignup
      module_function

      # Returns the invite when gating requires one and the token/email pair is valid.
      # Raises Tribetip::Errors::* on failure when signup is gated.
      def call(email:, token:)
        unless Tribetip::Launch.signup_gated?
          return nil if token.blank?

          invite = Invites.resolve(token)
          return nil unless invite
          assert_email_match!(invite, email)
          return invite
        end

        if token.blank?
          raise Tribetip::Errors::Authorization.new("An early access invite is required to sign up.")
        end

        invite = Invites.resolve(token)
        unless invite
          raise Tribetip::Errors::Authorization.new("This invite is invalid, expired, or already used.")
        end

        assert_email_match!(invite, email)
        invite
      end

      def assert_email_match!(invite, email)
        normalized = Invites.normalize_email(email)
        return if invite.email == normalized

        raise Tribetip::Errors::Authorization.new("Sign up must use the invited email address.")
      end
    end
  end
end

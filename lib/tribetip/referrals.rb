# frozen_string_literal: true

module Tribetip
  module Referrals
    USERNAME_PATTERN = /\A[a-z0-9_]{3,30}\z/

    module_function

    def normalize_username(value)
      value.to_s.strip.sub(/\A@+/, "").downcase.presence
    end

    def normalize_input(value)
      raw = value.to_s.strip
      return if raw.blank?
      return raw if Invites.valid_token_format?(raw)

      normalize_username(raw)
    end

    def valid_username_code?(value)
      normalize_username(value)&.match?(USERNAME_PATTERN) == true
    end

    def valid_input?(value)
      raw = value.to_s.strip
      return false if raw.blank?

      Invites.valid_token_format?(raw) || valid_username_code?(raw)
    end

    # Backward compatibility for existing callers.
    def normalize_code(value)
      normalize_input(value)
    end

    def valid_code_format?(value)
      valid_input?(value)
    end

    def eligible_referrer?(tribe)
      Config.enabled? &&
        tribe.referrals_enabled? &&
        tribe.creator? &&
        !tribe.suspended? &&
        tribe.paystack_onboarding_complete?
    end

    def signup_path(code)
      "/sign-up?ref=#{CGI.escape(code.to_s)}"
    end

    def signup_url(code)
      "#{Tribetip::Platform.app_url}#{signup_path(code)}"
    end
  end
end

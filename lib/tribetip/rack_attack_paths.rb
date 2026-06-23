# frozen_string_literal: true

module Tribetip
  module RackAttackPaths
    AUTH_PATHS = [
      "/tribes/sign_in",
      "/tribes/password",
      "/tribes"
    ].freeze

    PUBLIC_PROFILE_PATTERN = %r{\A/tribes/[a-z0-9_]+\z}
    SHARE_PROFILE_PATTERN = %r{\A/share/([A-Za-z0-9_-]{20,48})\z}
    WIDGET_CONFIG_PATH = "/widget/config"
    ACCOUNT_NUMBER_REVEAL_PATH = "/me/paystack/account_number"
    SESSION_REFRESH_PATH = "/tribes/session/refresh"

    module_function

    def normalize(path)
      path.to_s.sub(/\.(json|xml)\z/, "")
    end

    def auth_path?(request)
      request.post? && normalize(request.path).in?(AUTH_PATHS)
    end

    def sign_in_path?(request)
      request.post? && normalize(request.path) == "/tribes/sign_in"
    end

    def password_path?(request)
      request.post? && normalize(request.path) == "/tribes/password"
    end

    def public_profile_path?(request)
      request.get? && request.path.match?(PUBLIC_PROFILE_PATTERN)
    end

    def share_profile_path?(request)
      request.get? && request.path.match?(SHARE_PROFILE_PATTERN)
    end

    def widget_config_path?(request)
      request.get? && request.path == WIDGET_CONFIG_PATH
    end

    def account_number_reveal_path?(request)
      request.get? && normalize(request.path) == ACCOUNT_NUMBER_REVEAL_PATH
    end

    def session_refresh_path?(request)
      request.post? && normalize(request.path) == SESSION_REFRESH_PATH
    end
  end
end

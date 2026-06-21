# frozen_string_literal: true

module Tribetip
  module RackAttackPaths
    AUTH_PATHS = [
      "/tribes/sign_in",
      "/tribes/password",
      "/tribes"
    ].freeze

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
  end
end

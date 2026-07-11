# frozen_string_literal: true

module Tribetip
  module Middleware
    class InjectJwtFromCookie
      def initialize(app)
        @app = app
      end

      def call(env)
        if Tribetip::Security::AuthCookie.enabled?
          request = ActionDispatch::Request.new(env)
          if request.authorization.blank?
            token = Tribetip::Security::AuthCookie.read(request.cookies) ||
              read_from_cookie_header(env["HTTP_COOKIE"])
            if token.present?
              env["HTTP_AUTHORIZATION"] = "Bearer #{token}"
              env["tribetip.jwt_from_cookie"] = "1"
            end
          end
        end

        @app.call(env)
      end

      private

      def read_from_cookie_header(cookie_header)
        cookie_header.to_s.split(";").each do |part|
          key, value = part.strip.split("=", 2)
          next unless key == Tribetip::Security::AuthCookie::JWT_COOKIE

          return Rack::Utils.unescape(value.to_s).presence
        end

        nil
      end
    end
  end
end

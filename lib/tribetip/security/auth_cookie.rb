# frozen_string_literal: true

module Tribetip
  module Security
    module AuthCookie
      JWT_COOKIE = "tribetip_jwt"
      CSRF_COOKIE = "tribetip_csrf"

      module_function

      def enabled?
        ActiveModel::Type::Boolean.new.cast(ENV.fetch("TRIBETIP_AUTH_COOKIE_ENABLED", "true"))
      end

      def read(cookies)
        return nil unless enabled?

        cookies[JWT_COOKIE].presence
      end

      def write(cookies:, token:)
        return nil unless enabled?

        csrf_token = SecureRandom.urlsafe_base64(32)
        cookies[JWT_COOKIE] = jwt_cookie_options(token)
        cookies[CSRF_COOKIE] = csrf_cookie_options(csrf_token)
        csrf_token
      end

      def clear(cookies)
        cookies.delete(JWT_COOKIE, delete_options)
        cookies.delete(CSRF_COOKIE, delete_options)
      end

      def jwt_cookie_options(value)
        {
          value: value,
          httponly: true,
          secure: secure_cookies?,
          same_site: :lax,
          path: "/",
          max_age: jwt_max_age,
          domain: cookie_domain
        }.compact
      end

      def csrf_cookie_options(value)
        {
          value: value,
          httponly: false,
          secure: secure_cookies?,
          same_site: :lax,
          path: "/",
          max_age: jwt_max_age,
          domain: cookie_domain
        }.compact
      end

      def delete_options
        { path: "/", domain: cookie_domain }.compact
      end

      def jwt_max_age
        ENV.fetch("DEVISE_JWT_EXPIRATION_SECONDS", 4.hours.to_i).to_i
      end

      def cookie_domain
        return nil if Rails.env.local?

        ENV.fetch("TRIBETIP_AUTH_COOKIE_DOMAIN", ".tribetip.africa")
      end

      def secure_cookies?
        !Rails.env.local?
      end
    end
  end
end

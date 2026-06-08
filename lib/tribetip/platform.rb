# frozen_string_literal: true

module Tribetip
  module Platform
    DEFAULTS = {
      development: {
        platform_url: "http://localhost:3000",
        api_url: "http://localhost:3001"
      },
      production: {
        platform_url: "https://tribetip.africa",
        api_url: "https://api.tribetip.africa"
      },
      test: {
        platform_url: "http://localhost:3000",
        api_url: "http://localhost:3001"
      }
    }.freeze

    class << self
      def app_url
        normalize(fetch_url("TRIBETIP_PLATFORM_URL", default_for(:platform_url)))
      end

      def api_url
        normalize(fetch_url("TRIBETIP_API_URL", default_for(:api_url)))
      end

      def app_host
        URI.parse(app_url).host
      end

      def creator_page_url(username)
        "#{app_url}/#{username}"
      end

      def cors_origins
        explicit = ENV.fetch("CORS_ALLOWED_ORIGINS", "")
                          .split(",")
                          .map(&:strip)
                          .reject(&:empty?)
        return explicit unless explicit.empty?

        origins = [ app_url ]
        origins << app_url.sub("localhost", "127.0.0.1") if app_url.include?("localhost")
        origins.uniq
      end

      def mailer_url_options
        uri = URI.parse(app_url)
        options = { host: uri.host, protocol: uri.scheme }
        options[:port] = uri.port unless uri.port == uri.default_port
        options
      end

      private

      def fetch_url(key, fallback)
        ENV.fetch(key, fallback)
      end

      def normalize(url)
        url.to_s.delete_suffix("/")
      end

      def default_for(key)
        DEFAULTS.fetch(Rails.env.to_sym, DEFAULTS[:development])[key]
      end
    end
  end
end

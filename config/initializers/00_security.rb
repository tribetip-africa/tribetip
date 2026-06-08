# frozen_string_literal: true

module Tribetip
  module Security
    PRODUCTION_REQUIRED_ENV = %w[
      DEVISE_JWT_SECRET_KEY
      APP_HOSTS
      TRIBETIP_DATABASE_PASSWORD
    ].freeze

    class << self
      def require_email_confirmation?
        ActiveModel::Type::Boolean.new.cast(
          ENV.fetch("TRIBETIP_REQUIRE_EMAIL_CONFIRMATION") { Rails.env.production? }
        )
      end

      def validate_production_config!
        return unless Rails.env.production?

        missing = PRODUCTION_REQUIRED_ENV.select { |key| ENV[key].blank? }
        return if missing.empty?

        raise <<~MSG
          Missing required production environment variables: #{missing.join(", ")}

          See .env.example and config/deploy.yml for required values.
        MSG
      end
    end
  end
end

Tribetip::Security.validate_production_config!

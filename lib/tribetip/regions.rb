# frozen_string_literal: true

module Tribetip
  module Regions
    METADATA = {
      "NG" => { name: "Nigeria", currency: "NGN", flag: "🇳🇬" },
      "GH" => { name: "Ghana", currency: "GHS", flag: "🇬🇭" },
      "KE" => { name: "Kenya", currency: "KES", flag: "🇰🇪" },
      "ZA" => { name: "South Africa", currency: "ZAR", flag: "🇿🇦" },
      "CI" => { name: "Côte d'Ivoire", currency: "XOF", flag: "🇨🇮" }
    }.freeze

    class << self
      def enabled?(country_code)
        code = country_code.to_s.upcase
        flags.fetch(code, false)
      end

      def enabled_country_codes
        flags.select { |_code, enabled| enabled }.keys.sort
      end

      def default_country_code
        return "KE" if enabled?("KE")

        enabled_country_codes.first || "KE"
      end

      def default_currency
        METADATA.fetch(default_country_code).fetch(:currency)
      end

      def as_json
        METADATA.map do |code, meta|
          meta.merge(
            code: code,
            enabled: enabled?(code)
          )
        end.sort_by { |region| region[:code] }
      end

      def reset!
        @flags = nil
      end

      private

      def flags
        @flags ||= build_flags
      end

      def build_flags
        base = config_flags.stringify_keys
        apply_env_overrides(base)
      end

      def config_flags
        Rails.application.config_for(:regions).fetch(:flags)
      end

      def apply_env_overrides(base)
        if ENV["TRIBETIP_ENABLED_REGIONS"].present?
          enabled_set = ENV["TRIBETIP_ENABLED_REGIONS"]
                                .split(",")
                                .map { |code| code.strip.upcase }
                                .reject(&:empty?)
          return base.keys.index_with { |code| enabled_set.include?(code) }
        end

        METADATA.each_key do |code|
          env_key = "TRIBETIP_REGION_#{code}_ENABLED"
          next unless ENV.key?(env_key)

          base[code] = ActiveModel::Type::Boolean.new.cast(ENV[env_key])
        end

        base
      end
    end
  end
end

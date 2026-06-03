# frozen_string_literal: true

module Tribetip
  class SecureCache
    class SecurityError < StandardError; end

    VERSION_KEY_PREFIX = "secure_cache:version"
    FORBIDDEN_KEY_FRAGMENTS = %w[
      password token secret bearer authorization jwt encrypted
      sign_in sign_out session cookie
    ].freeze

    SCOPES = {
      public: { ttl: 5.minutes },
      private: { ttl: 1.minute }
    }.freeze

    class << self
      def fetch(key, scope: :public, ttl: nil, &block)
        validate_key!(key)
        validate_scope!(scope)
        raise SecurityError, "Refusing to cache sensitive key: #{key}" if sensitive_key?(key)

        Rails.cache.fetch(
          namespaced_key(key, scope),
          expires_in: ttl || SCOPES.fetch(scope).fetch(:ttl),
          &block
        )
      end

      def read(key, scope: :public)
        validate_key!(key)
        validate_scope!(scope)

        Rails.cache.read(namespaced_key(key, scope))
      end

      def write(key, value, scope: :public, ttl: nil)
        validate_key!(key)
        validate_scope!(scope)
        raise SecurityError, "Refusing to cache sensitive key: #{key}" if sensitive_key?(key)

        Rails.cache.write(
          namespaced_key(key, scope),
          value,
          expires_in: ttl || SCOPES.fetch(scope).fetch(:ttl)
        )
      end

      def delete(key, scope: :public)
        validate_key!(key)
        validate_scope!(scope)

        Rails.cache.delete(namespaced_key(key, scope))
      end

      def bump_version!(namespace)
        validate_namespace!(namespace)
        Rails.cache.increment(version_key(namespace), 1, initial: 1)
      end

      def public_profile_key(username)
        "public_profile/#{username.to_s.downcase}"
      end

      private

      def namespaced_key(key, scope)
        "#{Rails.env}/#{scope}/v#{version_for(scope)}/#{digest_key(key)}"
      end

      def version_for(scope)
        Rails.cache.read(version_key(scope)) || 0
      end

      def version_key(namespace)
        "#{VERSION_KEY_PREFIX}:#{namespace}"
      end

      def digest_key(key)
        Digest::SHA256.hexdigest(sanitize_key(key))
      end

      def sanitize_key(key)
        key.to_s.gsub(/[^a-zA-Z0-9:_\-\/\.]/, "_")
      end

      def validate_key!(key)
        raise ArgumentError, "Cache key cannot be blank" if key.blank?
      end

      def validate_scope!(scope)
        raise ArgumentError, "Invalid cache scope: #{scope}" unless SCOPES.key?(scope)
      end

      def validate_namespace!(namespace)
        raise ArgumentError, "Invalid cache namespace" if namespace.blank?
        raise SecurityError, "Invalid cache namespace" if namespace.match?(/[^a-zA-Z0-9_\-]/)
      end

      def sensitive_key?(key)
        normalized = key.to_s.downcase
        FORBIDDEN_KEY_FRAGMENTS.any? { |fragment| normalized.include?(fragment) }
      end
    end
  end
end

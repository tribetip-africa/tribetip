# frozen_string_literal: true

module Tribetip
  class Idempotency
    class Conflict < StandardError; end

    class << self
      def with_key(scope:, key:)
        return yield if key.blank?

        existing = IdempotencyKey.find_active(scope: scope, key: key)
        return existing if existing

        result = yield
        IdempotencyKey.store!(
          scope: scope,
          key: key,
          response_code: result.fetch(:status),
          response_body: result.fetch(:body)
        )
      rescue ActiveRecord::RecordNotUnique
        IdempotencyKey.find_active(scope: scope, key: key) || raise
      end
    end
  end
end

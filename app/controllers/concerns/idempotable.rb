# frozen_string_literal: true

module Idempotable
  extend ActiveSupport::Concern

  private

  def idempotency_key_header
    request.headers["Idempotency-Key"].to_s.strip.presence
  end

  def with_idempotency(scope:, &block)
    key = idempotency_key_header
    return yield if key.blank?

    cached = IdempotencyKey.find_active(scope: scope, key: key)
    if cached
      return render json: cached.response_body, status: cached.response_code
    end

    result = yield
    IdempotencyKey.store!(
      scope: scope,
      key: key,
      response_code: result.fetch(:status),
      response_body: result.fetch(:body)
    )
    render json: result.fetch(:body), status: result.fetch(:status)
  rescue ActiveRecord::RecordNotUnique
    cached = IdempotencyKey.find_active(scope: scope, key: key)
    render json: cached.response_body, status: cached.response_code if cached
  end
end

# frozen_string_literal: true

require "digest"

module Idempotable
  extend ActiveSupport::Concern

  private

  def idempotency_key_header
    request.headers["Idempotency-Key"].to_s.strip.presence
  end

  def idempotency_namespace
    return "tribe:#{current_tribe.id}" if respond_to?(:current_tribe, true) && current_tribe.present?

    "public"
  end

  def idempotency_request_fingerprint
    Digest::SHA256.hexdigest(
      [
        request.request_method,
        request.path,
        request.raw_post.to_s
      ].join("\n")
    )
  end

  def find_idempotency_cache(scope)
    cached = IdempotencyKey.find_active(
      scope: scope,
      key: idempotency_key_header,
      namespace: idempotency_namespace
    )
    return unless cached
    return cached if cached.request_fingerprint == idempotency_request_fingerprint

    render_error(
      Tribetip::Errors::BadRequest.new(
        "Idempotency-Key was already used with a different request."
      )
    )
    nil
  end

  def store_idempotency_cache!(scope:, response_code:, response_body:)
    IdempotencyKey.store!(
      scope: scope,
      key: idempotency_key_header,
      namespace: idempotency_namespace,
      request_fingerprint: idempotency_request_fingerprint,
      response_code: response_code,
      response_body: response_body
    )
  end
end

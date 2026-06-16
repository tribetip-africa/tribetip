# frozen_string_literal: true

class IdempotencyKey < ApplicationRecord
  TTL = 24.hours

  validates :scope, presence: true
  validates :key, presence: true, uniqueness: { scope: %i[namespace scope] }
  validates :namespace, presence: true
  validates :request_fingerprint, presence: true
  validates :response_code, presence: true

  scope :active, -> { where("expires_at > ?", Time.current) }

  def self.store!(
    scope:,
    key:,
    response_code:,
    response_body:,
    namespace: "public",
    request_fingerprint: "unfingerprinted"
  )
    create!(
      scope: scope,
      key: key,
      namespace: namespace,
      request_fingerprint: request_fingerprint,
      response_code: response_code,
      response_body: response_body,
      expires_at: TTL.from_now
    )
  end

  def self.find_active(scope:, key:, namespace: "public")
    active.find_by(scope: scope, key: key, namespace: namespace)
  end
end

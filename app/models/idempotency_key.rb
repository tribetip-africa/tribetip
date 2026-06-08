# frozen_string_literal: true

class IdempotencyKey < ApplicationRecord
  TTL = 24.hours

  validates :scope, presence: true
  validates :key, presence: true, uniqueness: { scope: :scope }
  validates :response_code, presence: true

  scope :active, -> { where("expires_at > ?", Time.current) }

  def self.store!(scope:, key:, response_code:, response_body:)
    create!(
      scope: scope,
      key: key,
      response_code: response_code,
      response_body: response_body,
      expires_at: TTL.from_now
    )
  end

  def self.find_active(scope:, key:)
    active.find_by(scope: scope, key: key)
  end
end

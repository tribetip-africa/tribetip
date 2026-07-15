# frozen_string_literal: true

class EarlyAccessInvite < ApplicationRecord
  belongs_to :tribe, optional: true

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :email, presence: true
  validates :token, presence: true, uniqueness: { case_sensitive: true }
  validates :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil, used_at: nil) }
  scope :not_expired, -> { where(expires_at: Time.current..) }
  scope :available, -> { active.not_expired }

  def available?
    revoked_at.nil? && used_at.nil? && expires_at > Time.current
  end

  def revoke!
    update!(revoked_at: Time.current) unless revoked_at?
  end

  def burn!(tribe:)
    update!(used_at: Time.current, tribe: tribe)
  end
end

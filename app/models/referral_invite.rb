# frozen_string_literal: true

class ReferralInvite < ApplicationRecord
  belongs_to :referrer, class_name: "Tribe"

  validates :code, presence: true, uniqueness: { case_sensitive: true }
  validates :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil) }
  scope :not_expired, -> { where(expires_at: Time.current..) }

  def active?
    revoked_at.nil? && expires_at > Time.current
  end

  def revoke!
    update!(revoked_at: Time.current) unless revoked_at?
  end
end

# frozen_string_literal: true

class Referral < ApplicationRecord
  STATUSES = %w[pending qualified rewarded rejected].freeze

  belongs_to :referrer, class_name: "Tribe"
  belongs_to :referred, class_name: "Tribe"
  belongs_to :qualifying_tip, class_name: "Tip", optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :referral_code_used, presence: true
  validates :referred_id, uniqueness: true
  validate :referrer_and_referred_must_differ

  scope :pending, -> { where(status: "pending") }
  scope :qualified, -> { where(status: "qualified") }
  scope :rewarded, -> { where(status: "rewarded") }
  scope :rejected, -> { where(status: "rejected") }

  def pending?
    status == "pending"
  end

  def rejected?
    status == "rejected"
  end

  def rewarded?
    status == "rewarded"
  end

  private

  def referrer_and_referred_must_differ
    return if referrer_id.blank? || referred_id.blank?
    return unless referrer_id == referred_id

    errors.add(:referred, "cannot be the same as the referrer")
  end
end

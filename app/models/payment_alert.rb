# frozen_string_literal: true

class PaymentAlert < ApplicationRecord
  KINDS = %w[
    settlement_tribe_rejected
    stale_pending_tips
    webhook_backlog
    tip_payment_mismatch
    unsettled_paid_tip
    settlement_status_drift
    onboarding_drift
  ].freeze
  SEVERITIES = %w[warning critical].freeze

  validates :kind, inclusion: { in: KINDS }
  validates :severity, inclusion: { in: SEVERITIES }
  validates :title, :body, presence: true

  scope :recent_first, -> { order(created_at: :desc) }
  scope :unresolved, -> { where(resolved_at: nil) }

  def resolved?
    resolved_at.present?
  end

  def as_json(*)
    {
      id: id,
      kind: kind,
      severity: severity,
      title: title,
      body: body,
      metadata: metadata,
      resolved_at: resolved_at&.iso8601,
      created_at: created_at.iso8601
    }
  end
end

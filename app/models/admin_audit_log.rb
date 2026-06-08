# frozen_string_literal: true

class AdminAuditLog < ApplicationRecord
  ACTIONS = %w[
    suspend_tribe
    activate_tribe
    replay_paystack_event
    paystack_audit_sync
  ].freeze

  belongs_to :admin, class_name: "Tribe", foreign_key: :admin_id, inverse_of: false

  validates :action, inclusion: { in: ACTIONS }
  validates :target_type, presence: true
  validates :target_id, presence: true

  scope :recent_first, -> { order(created_at: :desc) }

  def as_json(*)
    {
      id: id,
      admin_id: admin_id,
      action: action,
      target_type: target_type,
      target_id: target_id,
      details: details,
      request_id: request_id,
      ip: ip,
      user_agent: user_agent,
      created_at: created_at
    }
  end
end

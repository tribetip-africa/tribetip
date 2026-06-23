# frozen_string_literal: true

class TribeAuditLog < ApplicationRecord
  ACTIONS = %w[
    account_number_revealed
  ].freeze

  belongs_to :tribe

  validates :action, inclusion: { in: ACTIONS }

  scope :recent_first, -> { order(created_at: :desc) }

  def as_json(*)
    {
      id: id,
      tribe_id: tribe_id,
      action: action,
      details: details,
      request_id: request_id,
      ip: ip,
      user_agent: user_agent,
      created_at: created_at
    }
  end
end

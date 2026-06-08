# frozen_string_literal: true

class TipEvent < ApplicationRecord
  ACTIONS = %w[
    created
    checkout_ready
    checkout_failed
    reconcile_attempted
    paid
    failed
  ].freeze
  SOURCES = %w[webhook reconcile sweep checkout_job public system admin].freeze

  belongs_to :tip
  belongs_to :paystack_event, optional: true

  validates :action, inclusion: { in: ACTIONS }
  validates :source, inclusion: { in: SOURCES }
  validates :paystack_reference, presence: true

  scope :recent_first, -> { order(created_at: :desc) }

  def as_json(*)
    {
      id: id,
      tip_id: tip_id,
      paystack_event_id: paystack_event_id,
      action: action,
      from_status: from_status,
      to_status: to_status,
      source: source,
      actor_id: actor_id,
      paystack_reference: paystack_reference,
      paid_via: paid_via,
      failed_reason: failed_reason,
      verification: verification,
      metadata: metadata,
      request_id: request_id,
      ip: ip,
      created_at: created_at
    }
  end
end

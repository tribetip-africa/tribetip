# frozen_string_literal: true

class Tip < ApplicationRecord
  VALID_STATUSES = %w[pending paid failed].freeze
  VALID_PAID_VIA = %w[webhook reconcile sweep].freeze

  belongs_to :tribe
  has_many :tip_events, dependent: :destroy
  belongs_to :last_paystack_event, class_name: "PaystackEvent", optional: true

  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, inclusion: { in: Tribe::VALID_CURRENCIES }
  validates :status, inclusion: { in: VALID_STATUSES }
  validates :paystack_reference, presence: true, uniqueness: true
  validates :supporter_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :message, length: { maximum: 280 }, allow_blank: true
  validates :paid_via, inclusion: { in: VALID_PAID_VIA }, allow_nil: true

  scope :paid, -> { where(status: "paid") }
  scope :pending_older_than, lambda { |duration|
    where(status: "pending").where(created_at: ...duration.ago)
  }
  scope :recent_first, -> { order(created_at: :desc) }

  def pending?
    status == "pending"
  end

  def paid?
    status == "paid"
  end

  def mark_paid!(via: nil, paystack_event: nil, verification: nil, source: nil, actor_id: nil, request_context: nil)
    from_status = status
    attrs = { status: "paid", paid_at: Time.current, failed_reason: nil }
    attrs[:paid_via] = via if via.present?
    attrs[:last_paystack_event_id] = paystack_event.id if paystack_event

    update!(attrs)
    record_status_event(
      action: "paid",
      from_status: from_status,
      to_status: "paid",
      source: source || via&.to_s || "system",
      actor_id: actor_id,
      paystack_event: paystack_event,
      paid_via: via,
      verification: verification,
      request_context: request_context
    )
  end

  def mark_failed!(
    reason: nil,
    paystack_event: nil,
    verification: nil,
    source: nil,
    actor_id: nil,
    request_context: nil
  )
    from_status = status
    attrs = { status: "failed", failed_reason: reason }
    attrs[:last_paystack_event_id] = paystack_event.id if paystack_event

    update!(attrs)
    record_status_event(
      action: "failed",
      from_status: from_status,
      to_status: "failed",
      source: source || "system",
      actor_id: actor_id,
      paystack_event: paystack_event,
      failed_reason: reason,
      verification: verification,
      request_context: request_context
    )
  end

  def record_created_event!(source: "public", request_context: nil)
    Tribetip::Audit::RecordTipEvent.call(
      tip: self,
      action: "created",
      from_status: nil,
      to_status: "pending",
      source: source,
      request_context: request_context
    )
  end

  def self.generate_reference
    "tip_#{SecureRandom.hex(12)}"
  end

  private

  def record_status_event(**kwargs)
    Tribetip::Audit::RecordTipEvent.call(tip: self, **kwargs)
  end
end

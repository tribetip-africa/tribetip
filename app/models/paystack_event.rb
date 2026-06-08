# frozen_string_literal: true

class PaystackEvent < ApplicationRecord
  belongs_to :tip, optional: true

  STATUSES = %w[pending processing processed failed].freeze
  RETRYABLE_EVENT_TYPES = %w[charge.success charge.failed].freeze
  RETRY_WINDOW = 7.days

  validates :event_id, presence: true, uniqueness: true
  validates :event_type, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :recent_first, -> { order(created_at: :desc) }
  scope :failed, -> { where(status: "failed") }
  scope :retryable, lambda {
    failed
      .where(event_type: RETRYABLE_EVENT_TYPES)
      .where(created_at: RETRY_WINDOW.ago..)
  }

  def processed?
    status == "processed"
  end

  def mark_processing!
    update!(status: "processing")
  end

  def mark_processed!
    update!(status: "processed", processed_at: Time.current, error_message: nil)
  end

  def mark_failed!(message)
    update!(status: "failed", error_message: message, processed_at: Time.current)
  end

  def replayable?
    status == "failed"
  end

  def replay!
    raise ArgumentError, "Only failed events can be replayed" unless replayable?

    update!(status: "pending", error_message: nil, processed_at: nil)
    Paystack::ProcessWebhookJob.perform_later(id)
  end
end

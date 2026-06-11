# frozen_string_literal: true

class CreatorNotification < ApplicationRecord
  KINDS = %w[settlement_paid settlement_failed].freeze

  belongs_to :tribe

  validates :kind, inclusion: { in: KINDS }
  validates :title, :body, presence: true

  scope :recent_first, -> { order(created_at: :desc) }
  scope :unread, -> { where(read_at: nil) }

  def read?
    read_at.present?
  end

  def mark_read!
    update!(read_at: Time.current) unless read?
  end

  def as_json(*)
    {
      id: id,
      kind: kind,
      title: title,
      body: body,
      metadata: metadata,
      read_at: read_at&.iso8601,
      created_at: created_at.iso8601
    }
  end
end

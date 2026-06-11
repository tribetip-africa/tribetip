# frozen_string_literal: true

class PaystackSettlement < ApplicationRecord
  STATUSES = Tribetip::Paystack::SettlementRecord::STATUSES

  belongs_to :tribe
  belongs_to :paystack_event, optional: true
  belongs_to :tip, optional: true

  validates :paystack_transfer_code, presence: true, uniqueness: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, presence: true, inclusion: { in: Tribe::VALID_CURRENCIES }
  validates :status, inclusion: { in: STATUSES }

  scope :recent_first, -> { order(Arel.sql("COALESCE(settled_at, created_at) DESC")) }

  def to_settlement_record
    Tribetip::Paystack::SettlementRecord.from_stored(self)
  end
end

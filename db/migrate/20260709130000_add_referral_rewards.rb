# frozen_string_literal: true

class AddReferralRewards < ActiveRecord::Migration[8.0]
  def change
    add_column :tribes, :referral_fee_credit_cents_remaining, :integer, null: false, default: 0

    change_table :referrals, bulk: true do |t|
      t.references :qualifying_tip, foreign_key: { to_table: :tips }, type: :uuid, index: true
      t.integer :referrer_bonus_cents
      t.string :referrer_bonus_currency
      t.string :referrer_bonus_reference
      t.string :referrer_bonus_transfer_code
    end

    add_index :referrals, :referrer_bonus_reference, unique: true, where: "referrer_bonus_reference IS NOT NULL"
  end
end

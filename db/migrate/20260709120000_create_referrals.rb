# frozen_string_literal: true

class CreateReferrals < ActiveRecord::Migration[8.0]
  def change
    add_reference :tribes, :referred_by, foreign_key: { to_table: :tribes }, type: :uuid, index: true

    create_table :referrals, id: :uuid do |t|
      t.references :referrer, null: false, foreign_key: { to_table: :tribes }, type: :uuid
      t.references :referred, null: false, foreign_key: { to_table: :tribes }, type: :uuid, index: { unique: true }
      t.string :status, null: false, default: "pending"
      t.string :referral_code_used, null: false
      t.datetime :qualified_at
      t.datetime :rewarded_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :referrals, %i[referrer_id status]
    add_index :referrals, %i[status created_at]
  end
end

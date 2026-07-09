# frozen_string_literal: true

class CreateReferralInvites < ActiveRecord::Migration[8.0]
  def change
    create_table :referral_invites, id: :uuid do |t|
      t.references :referrer, null: false, foreign_key: { to_table: :tribes }, type: :uuid
      t.string :code, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :referral_invites, :code, unique: true
    add_index :referral_invites, %i[referrer_id revoked_at expires_at]
  end
end

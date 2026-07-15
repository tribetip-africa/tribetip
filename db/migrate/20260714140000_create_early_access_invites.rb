# frozen_string_literal: true

class CreateEarlyAccessInvites < ActiveRecord::Migration[8.0]
  def change
    create_table :early_access_invites, id: :uuid do |t|
      t.string :email, null: false
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.datetime :used_at
      t.references :tribe, null: true, foreign_key: true, type: :uuid
      t.timestamps
    end

    add_index :early_access_invites, :token, unique: true
    add_index :early_access_invites, :email
    add_index :early_access_invites, %i[used_at revoked_at expires_at]
  end
end

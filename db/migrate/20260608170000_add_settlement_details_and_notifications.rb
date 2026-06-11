# frozen_string_literal: true

class AddSettlementDetailsAndNotifications < ActiveRecord::Migration[8.0]
  def change
    add_reference :paystack_settlements, :tip, null: true, foreign_key: true, type: :uuid

    create_table :creator_notifications, id: :uuid do |t|
      t.references :tribe, null: false, foreign_key: true, type: :uuid
      t.string :kind, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :read_at

      t.timestamps
    end

    add_index :creator_notifications, %i[tribe_id created_at]
    add_index :creator_notifications, %i[tribe_id read_at]
  end
end

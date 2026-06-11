# frozen_string_literal: true

class CreatePaystackSettlements < ActiveRecord::Migration[8.0]
  def change
    create_table :paystack_settlements, id: :uuid do |t|
      t.references :tribe, null: false, foreign_key: true, type: :uuid
      t.references :paystack_event, null: true, foreign_key: true, type: :uuid
      t.string :paystack_transfer_code, null: false
      t.integer :amount_cents, null: false
      t.string :currency, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :settled_at
      t.string :destination
      t.string :reference
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :paystack_settlements, :paystack_transfer_code, unique: true
    add_index :paystack_settlements, %i[tribe_id settled_at]
    add_index :paystack_settlements, :status
  end
end

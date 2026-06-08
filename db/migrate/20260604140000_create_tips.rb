# frozen_string_literal: true

class CreateTips < ActiveRecord::Migration[8.0]
  def change
    create_table :tips, id: :uuid do |t|
      t.references :tribe, null: false, foreign_key: true, type: :uuid
      t.integer :amount_cents, null: false
      t.string :currency, null: false
      t.string :status, null: false, default: "pending"
      t.string :paystack_reference, null: false
      t.string :supporter_email
      t.string :supporter_name
      t.text :message
      t.jsonb :paystack_metadata, null: false, default: {}
      t.datetime :paid_at

      t.timestamps
    end

    add_index :tips, :paystack_reference, unique: true
    add_index :tips, [ :tribe_id, :status ]
    add_index :tips, [ :tribe_id, :created_at ]
  end
end

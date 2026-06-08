# frozen_string_literal: true

class CreatePaystackEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :paystack_events, id: :uuid do |t|
      t.string :event_id, null: false
      t.string :event_type, null: false
      t.string :status, null: false, default: "pending"
      t.jsonb :payload, null: false, default: {}
      t.text :error_message
      t.datetime :processed_at

      t.timestamps
    end

    add_index :paystack_events, :event_id, unique: true
    add_index :paystack_events, :status
    add_index :paystack_events, :created_at
  end
end

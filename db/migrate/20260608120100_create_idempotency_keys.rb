# frozen_string_literal: true

class CreateIdempotencyKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :idempotency_keys, id: :uuid do |t|
      t.string :scope, null: false
      t.string :key, null: false
      t.integer :response_code, null: false
      t.jsonb :response_body, null: false, default: {}
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :idempotency_keys, %i[scope key], unique: true
    add_index :idempotency_keys, :expires_at
  end
end

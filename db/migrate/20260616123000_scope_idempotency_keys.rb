# frozen_string_literal: true

class ScopeIdempotencyKeys < ActiveRecord::Migration[8.0]
  def change
    add_column :idempotency_keys, :namespace, :string, null: false, default: "public"
    add_column :idempotency_keys, :request_fingerprint, :string, null: false, default: "unfingerprinted"

    remove_index :idempotency_keys, %i[scope key]
    add_index :idempotency_keys, %i[scope namespace key], unique: true
  end
end

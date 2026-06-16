# frozen_string_literal: true

class CreatePaymentAlerts < ActiveRecord::Migration[8.0]
  def change
    create_table :payment_alerts, id: :uuid do |t|
      t.string :kind, null: false
      t.string :severity, null: false, default: "warning"
      t.string :title, null: false
      t.text :body, null: false
      t.jsonb :metadata, null: false, default: {}

      t.datetime :resolved_at
      t.timestamps
    end

    add_index :payment_alerts, :kind
    add_index :payment_alerts, :resolved_at
    add_index :payment_alerts, :created_at
  end
end

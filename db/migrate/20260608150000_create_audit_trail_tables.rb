# frozen_string_literal: true

class CreateAuditTrailTables < ActiveRecord::Migration[8.0]
  def change
    create_table :tip_events, id: :uuid do |t|
      t.uuid :tip_id, null: false
      t.uuid :paystack_event_id
      t.string :action, null: false
      t.string :from_status
      t.string :to_status
      t.string :source, null: false
      t.string :actor_id
      t.string :paystack_reference, null: false
      t.string :paid_via
      t.text :failed_reason
      t.jsonb :verification, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.string :request_id
      t.string :ip

      t.datetime :created_at, null: false
    end

    add_index :tip_events, :tip_id
    add_index :tip_events, :paystack_event_id
    add_index :tip_events, :paystack_reference
    add_index :tip_events, :created_at
    add_index :tip_events, %i[tip_id created_at]

    create_table :admin_audit_logs, id: :uuid do |t|
      t.uuid :admin_id, null: false
      t.string :action, null: false
      t.string :target_type, null: false
      t.string :target_id, null: false
      t.jsonb :details, null: false, default: {}
      t.string :request_id
      t.string :ip
      t.string :user_agent

      t.datetime :created_at, null: false
    end

    add_index :admin_audit_logs, :admin_id
    add_index :admin_audit_logs, %i[target_type target_id]
    add_index :admin_audit_logs, :action
    add_index :admin_audit_logs, :created_at

    add_reference :paystack_events, :tip, type: :uuid, foreign_key: true, index: true
    add_column :tips, :last_paystack_event_id, :uuid
    add_column :tips, :failed_reason, :text
    add_index :tips, :last_paystack_event_id
  end
end

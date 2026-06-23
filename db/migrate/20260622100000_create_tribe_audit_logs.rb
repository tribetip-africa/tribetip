# frozen_string_literal: true

class CreateTribeAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :tribe_audit_logs, id: :uuid do |t|
      t.uuid :tribe_id, null: false
      t.string :action, null: false
      t.jsonb :details, null: false, default: {}
      t.string :request_id
      t.string :ip
      t.string :user_agent

      t.datetime :created_at, null: false
    end

    add_index :tribe_audit_logs, :tribe_id
    add_index :tribe_audit_logs, :action
    add_index :tribe_audit_logs, :created_at
    add_index :tribe_audit_logs, %i[tribe_id created_at]
  end
end

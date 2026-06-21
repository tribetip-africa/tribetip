# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_06_16_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"
  enable_extension "uuid-ossp"

  create_table "admin_audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "admin_id", null: false
    t.string "action", null: false
    t.string "target_type", null: false
    t.string "target_id", null: false
    t.jsonb "details", default: {}, null: false
    t.string "request_id"
    t.string "ip"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.index ["action"], name: "index_admin_audit_logs_on_action"
    t.index ["admin_id"], name: "index_admin_audit_logs_on_admin_id"
    t.index ["created_at"], name: "index_admin_audit_logs_on_created_at"
    t.index ["target_type", "target_id"], name: "index_admin_audit_logs_on_target_type_and_target_id"
  end

  create_table "creator_notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tribe_id", null: false
    t.string "kind", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tribe_id", "created_at"], name: "index_creator_notifications_on_tribe_id_and_created_at"
    t.index ["tribe_id", "read_at"], name: "index_creator_notifications_on_tribe_id_and_read_at"
    t.index ["tribe_id"], name: "index_creator_notifications_on_tribe_id"
  end

  create_table "idempotency_keys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "scope", null: false
    t.string "key", null: false
    t.integer "response_code", null: false
    t.jsonb "response_body", default: {}, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "namespace", default: "public", null: false
    t.string "request_fingerprint", default: "unfingerprinted", null: false
    t.index ["expires_at"], name: "index_idempotency_keys_on_expires_at"
    t.index ["scope", "namespace", "key"], name: "index_idempotency_keys_on_scope_and_namespace_and_key", unique: true
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.string "jti", null: false
    t.datetime "exp", null: false
    t.index ["exp"], name: "index_jwt_denylists_on_exp"
    t.index ["jti"], name: "index_jwt_denylists_on_jti", unique: true
  end

  create_table "payment_alerts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "kind", null: false
    t.string "severity", default: "warning", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_payment_alerts_on_created_at"
    t.index ["kind"], name: "index_payment_alerts_on_kind"
    t.index ["resolved_at"], name: "index_payment_alerts_on_resolved_at"
  end

  create_table "paystack_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "event_id", null: false
    t.string "event_type", null: false
    t.string "status", default: "pending", null: false
    t.jsonb "payload", default: {}, null: false
    t.text "error_message"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "tip_id"
    t.index ["created_at"], name: "index_paystack_events_on_created_at"
    t.index ["event_id"], name: "index_paystack_events_on_event_id", unique: true
    t.index ["status"], name: "index_paystack_events_on_status"
    t.index ["tip_id"], name: "index_paystack_events_on_tip_id"
  end

  create_table "paystack_settlements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tribe_id", null: false
    t.uuid "paystack_event_id"
    t.string "paystack_transfer_code", null: false
    t.integer "amount_cents", null: false
    t.string "currency", null: false
    t.string "status", default: "pending", null: false
    t.datetime "settled_at"
    t.string "destination"
    t.string "reference"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "tip_id"
    t.index ["paystack_event_id"], name: "index_paystack_settlements_on_paystack_event_id"
    t.index ["paystack_transfer_code"], name: "index_paystack_settlements_on_paystack_transfer_code", unique: true
    t.index ["status"], name: "index_paystack_settlements_on_status"
    t.index ["tip_id"], name: "index_paystack_settlements_on_tip_id"
    t.index ["tribe_id", "settled_at"], name: "index_paystack_settlements_on_tribe_id_and_settled_at"
    t.index ["tribe_id", "tip_id"], name: "index_paystack_settlements_on_tribe_id_and_tip_id_unique", unique: true, where: "(tip_id IS NOT NULL)"
    t.index ["tribe_id"], name: "index_paystack_settlements_on_tribe_id"
  end

  create_table "tip_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tip_id", null: false
    t.uuid "paystack_event_id"
    t.string "action", null: false
    t.string "from_status"
    t.string "to_status"
    t.string "source", null: false
    t.string "actor_id"
    t.string "paystack_reference", null: false
    t.string "paid_via"
    t.text "failed_reason"
    t.jsonb "verification", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "request_id"
    t.string "ip"
    t.datetime "created_at", null: false
    t.index ["created_at"], name: "index_tip_events_on_created_at"
    t.index ["paystack_event_id"], name: "index_tip_events_on_paystack_event_id"
    t.index ["paystack_reference"], name: "index_tip_events_on_paystack_reference"
    t.index ["tip_id", "created_at"], name: "index_tip_events_on_tip_id_and_created_at"
    t.index ["tip_id"], name: "index_tip_events_on_tip_id"
  end

  create_table "tips", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tribe_id", null: false
    t.integer "amount_cents", null: false
    t.string "currency", null: false
    t.string "status", default: "pending", null: false
    t.string "paystack_reference", null: false
    t.string "supporter_email"
    t.string "supporter_name"
    t.text "message"
    t.jsonb "paystack_metadata", default: {}, null: false
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "paid_via"
    t.uuid "last_paystack_event_id"
    t.text "failed_reason"
    t.index ["last_paystack_event_id"], name: "index_tips_on_last_paystack_event_id"
    t.index ["paid_via"], name: "index_tips_on_paid_via", where: "(paid_via IS NOT NULL)"
    t.index ["paystack_reference"], name: "index_tips_on_paystack_reference", unique: true
    t.index ["tribe_id", "created_at"], name: "index_tips_on_tribe_id_and_created_at"
    t.index ["tribe_id", "status"], name: "index_tips_on_tribe_id_and_status"
    t.index ["tribe_id"], name: "index_tips_on_tribe_id"
  end

  create_table "tribes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username"
    t.string "display_name"
    t.text "bio"
    t.string "country_code", default: "KE", null: false
    t.string "currency", default: "KES", null: false
    t.integer "default_tip_amount_cents", default: 50000, null: false
    t.string "account_status", default: "pending", null: false
    t.boolean "is_profile_public", default: false, null: false
    t.datetime "onboarding_completed_at"
    t.datetime "terms_accepted_at"
    t.string "role", default: "creator", null: false
    t.string "paystack_customer_code"
    t.string "paystack_subaccount_code"
    t.string "paystack_provisioning_error"
    t.string "tip_share_token"
    t.string "widget_embed_token"
    t.boolean "widget_enabled", default: false, null: false
    t.string "widget_destination_url"
    t.string "widget_icon_url"
    t.string "widget_accent_color", default: "#247a45", null: false
    t.string "widget_position", default: "bottom-right", null: false
    t.string "widget_cta_text", default: "Tip me", null: false
    t.boolean "widget_open_same_tab", default: false, null: false
    t.index ["account_status"], name: "index_tribes_on_account_status"
    t.index ["confirmation_token"], name: "index_tribes_on_confirmation_token", unique: true
    t.index ["confirmed_at"], name: "index_tribes_on_confirmed_at", where: "(confirmed_at IS NOT NULL)"
    t.index ["country_code", "username"], name: "index_tribes_active_public_by_country", where: "((is_profile_public = true) AND ((account_status)::text = 'active'::text))"
    t.index ["country_code"], name: "index_tribes_on_country_code"
    t.index ["email"], name: "index_tribes_on_email", unique: true
    t.index ["paystack_customer_code"], name: "index_tribes_on_paystack_customer_code", unique: true, where: "(paystack_customer_code IS NOT NULL)"
    t.index ["paystack_subaccount_code"], name: "index_tribes_on_paystack_subaccount_code", unique: true, where: "(paystack_subaccount_code IS NOT NULL)"
    t.index ["reset_password_token"], name: "index_tribes_on_reset_password_token", unique: true
    t.index ["role"], name: "index_tribes_on_role"
    t.index ["tip_share_token"], name: "index_tribes_on_tip_share_token", unique: true, where: "(tip_share_token IS NOT NULL)"
    t.index ["unlock_token"], name: "index_tribes_on_unlock_token", unique: true
    t.index ["username"], name: "index_tribes_on_username", unique: true, where: "(username IS NOT NULL)"
    t.index ["widget_embed_token"], name: "index_tribes_on_widget_embed_token", unique: true, where: "(widget_embed_token IS NOT NULL)"
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.uuid "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.text "object_changes"
    t.string "request_id"
    t.string "ip"
    t.string "user_agent"
    t.index ["created_at"], name: "index_versions_on_created_at"
    t.index ["item_type", "item_id", "created_at"], name: "index_versions_on_item_type_item_id_and_created_at"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["request_id"], name: "index_versions_on_request_id"
  end

  add_foreign_key "creator_notifications", "tribes"
  add_foreign_key "paystack_events", "tips"
  add_foreign_key "paystack_settlements", "paystack_events"
  add_foreign_key "paystack_settlements", "tips"
  add_foreign_key "paystack_settlements", "tribes"
  add_foreign_key "tips", "tribes"
end

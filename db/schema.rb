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

ActiveRecord::Schema[8.1].define(version: 2026_07_16_064018) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"
  enable_extension "uuid-ossp"

  create_table "admin_audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.uuid "admin_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "details", default: {}, null: false
    t.string "ip"
    t.string "request_id"
    t.string "target_id", null: false
    t.string "target_type", null: false
    t.string "user_agent"
    t.index ["action"], name: "index_admin_audit_logs_on_action"
    t.index ["admin_id"], name: "index_admin_audit_logs_on_admin_id"
    t.index ["created_at"], name: "index_admin_audit_logs_on_created_at"
    t.index ["target_type", "target_id"], name: "index_admin_audit_logs_on_target_type_and_target_id"
  end

  create_table "creator_notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "read_at"
    t.string "title", null: false
    t.uuid "tribe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tribe_id", "created_at"], name: "index_creator_notifications_on_tribe_id_and_created_at"
    t.index ["tribe_id", "read_at"], name: "index_creator_notifications_on_tribe_id_and_read_at"
    t.index ["tribe_id"], name: "index_creator_notifications_on_tribe_id"
  end

  create_table "early_access_invites", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.string "token", null: false
    t.uuid "tribe_id"
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.index ["email"], name: "index_early_access_invites_on_email"
    t.index ["token"], name: "index_early_access_invites_on_token", unique: true
    t.index ["tribe_id"], name: "index_early_access_invites_on_tribe_id"
    t.index ["used_at", "revoked_at", "expires_at"], name: "idx_on_used_at_revoked_at_expires_at_14eee96eda"
  end

  create_table "idempotency_keys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.string "namespace", default: "public", null: false
    t.string "request_fingerprint", default: "unfingerprinted", null: false
    t.jsonb "response_body", default: {}, null: false
    t.integer "response_code", null: false
    t.string "scope", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_idempotency_keys_on_expires_at"
    t.index ["scope", "namespace", "key"], name: "index_idempotency_keys_on_scope_and_namespace_and_key", unique: true
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.datetime "exp", null: false
    t.string "jti", null: false
    t.index ["exp"], name: "index_jwt_denylists_on_exp"
    t.index ["jti"], name: "index_jwt_denylists_on_jti", unique: true
  end

  create_table "payment_alerts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "resolved_at"
    t.string "severity", default: "warning", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_payment_alerts_on_created_at"
    t.index ["kind"], name: "index_payment_alerts_on_kind"
    t.index ["resolved_at"], name: "index_payment_alerts_on_resolved_at"
  end

  create_table "paystack_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "event_id", null: false
    t.string "event_type", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "processed_at"
    t.string "status", default: "pending", null: false
    t.uuid "tip_id"
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_paystack_events_on_created_at"
    t.index ["event_id"], name: "index_paystack_events_on_event_id", unique: true
    t.index ["status"], name: "index_paystack_events_on_status"
    t.index ["tip_id"], name: "index_paystack_events_on_tip_id"
  end

  create_table "paystack_settlements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.string "destination"
    t.jsonb "metadata", default: {}, null: false
    t.uuid "paystack_event_id"
    t.string "paystack_transfer_code", null: false
    t.string "reference"
    t.datetime "settled_at"
    t.string "status", default: "pending", null: false
    t.uuid "tip_id"
    t.uuid "tribe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["paystack_event_id"], name: "index_paystack_settlements_on_paystack_event_id"
    t.index ["paystack_transfer_code"], name: "index_paystack_settlements_on_paystack_transfer_code", unique: true
    t.index ["status"], name: "index_paystack_settlements_on_status"
    t.index ["tip_id"], name: "index_paystack_settlements_on_tip_id"
    t.index ["tribe_id", "settled_at"], name: "index_paystack_settlements_on_tribe_id_and_settled_at"
    t.index ["tribe_id", "tip_id"], name: "index_paystack_settlements_on_tribe_id_and_tip_id_unique", unique: true, where: "(tip_id IS NOT NULL)"
    t.index ["tribe_id"], name: "index_paystack_settlements_on_tribe_id"
  end

  create_table "referral_invites", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.uuid "referrer_id", null: false
    t.datetime "revoked_at"
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_referral_invites_on_code", unique: true
    t.index ["referrer_id", "revoked_at", "expires_at"], name: "idx_on_referrer_id_revoked_at_expires_at_2e83356754"
    t.index ["referrer_id"], name: "index_referral_invites_on_referrer_id"
  end

  create_table "referrals", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "qualified_at"
    t.uuid "qualifying_tip_id"
    t.string "referral_code_used", null: false
    t.uuid "referred_id", null: false
    t.integer "referrer_bonus_cents"
    t.string "referrer_bonus_currency"
    t.string "referrer_bonus_reference"
    t.string "referrer_bonus_transfer_code"
    t.uuid "referrer_id", null: false
    t.datetime "rewarded_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["qualifying_tip_id"], name: "index_referrals_on_qualifying_tip_id"
    t.index ["referred_id"], name: "index_referrals_on_referred_id", unique: true
    t.index ["referrer_bonus_reference"], name: "index_referrals_on_referrer_bonus_reference", unique: true, where: "(referrer_bonus_reference IS NOT NULL)"
    t.index ["referrer_id", "status"], name: "index_referrals_on_referrer_id_and_status"
    t.index ["referrer_id"], name: "index_referrals_on_referrer_id"
    t.index ["status", "created_at"], name: "index_referrals_on_status_and_created_at"
  end

  create_table "tip_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.string "actor_id"
    t.datetime "created_at", null: false
    t.text "failed_reason"
    t.string "from_status"
    t.string "ip"
    t.jsonb "metadata", default: {}, null: false
    t.string "paid_via"
    t.uuid "paystack_event_id"
    t.string "paystack_reference", null: false
    t.string "request_id"
    t.string "source", null: false
    t.uuid "tip_id", null: false
    t.string "to_status"
    t.jsonb "verification", default: {}, null: false
    t.index ["created_at"], name: "index_tip_events_on_created_at"
    t.index ["paystack_event_id"], name: "index_tip_events_on_paystack_event_id"
    t.index ["paystack_reference"], name: "index_tip_events_on_paystack_reference"
    t.index ["tip_id", "created_at"], name: "index_tip_events_on_tip_id_and_created_at"
    t.index ["tip_id"], name: "index_tip_events_on_tip_id"
  end

  create_table "tips", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.text "failed_reason"
    t.uuid "last_paystack_event_id"
    t.text "message"
    t.datetime "paid_at"
    t.string "paid_via"
    t.jsonb "paystack_metadata", default: {}, null: false
    t.string "paystack_reference", null: false
    t.string "status", default: "pending", null: false
    t.string "supporter_email"
    t.string "supporter_name"
    t.uuid "tribe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["last_paystack_event_id"], name: "index_tips_on_last_paystack_event_id"
    t.index ["paid_via"], name: "index_tips_on_paid_via", where: "(paid_via IS NOT NULL)"
    t.index ["paystack_reference"], name: "index_tips_on_paystack_reference", unique: true
    t.index ["tribe_id", "created_at"], name: "index_tips_on_tribe_id_and_created_at"
    t.index ["tribe_id", "status"], name: "index_tips_on_tribe_id_and_status"
    t.index ["tribe_id"], name: "index_tips_on_tribe_id"
  end

  create_table "tribe_audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.jsonb "details", default: {}, null: false
    t.string "ip"
    t.string "request_id"
    t.uuid "tribe_id", null: false
    t.string "user_agent"
    t.index ["action"], name: "index_tribe_audit_logs_on_action"
    t.index ["created_at"], name: "index_tribe_audit_logs_on_created_at"
    t.index ["tribe_id", "created_at"], name: "index_tribe_audit_logs_on_tribe_id_and_created_at"
    t.index ["tribe_id"], name: "index_tribe_audit_logs_on_tribe_id"
  end

  create_table "tribes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "account_status", default: "pending", null: false
    t.text "bio"
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.string "country_code", default: "KE", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "KES", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.integer "default_tip_amount_cents", default: 50000, null: false
    t.string "display_name"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.boolean "is_profile_public", default: false, null: false
    t.datetime "last_password_authenticated_at"
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "locked_at"
    t.datetime "onboarding_completed_at"
    t.string "paystack_customer_code"
    t.string "paystack_provisioning_error"
    t.string "paystack_subaccount_code"
    t.integer "referral_fee_credit_cents_remaining", default: 0, null: false
    t.boolean "referrals_enabled", default: true, null: false
    t.uuid "referred_by_id"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "creator", null: false
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "terms_accepted_at"
    t.string "tip_share_token"
    t.string "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.string "username"
    t.string "widget_accent_color", default: "#247a45", null: false
    t.string "widget_cta_text", default: "Tip me", null: false
    t.string "widget_destination_url"
    t.string "widget_embed_token"
    t.boolean "widget_enabled", default: false, null: false
    t.string "widget_icon_url"
    t.boolean "widget_open_same_tab", default: false, null: false
    t.string "widget_position", default: "bottom-right", null: false
    t.index ["account_status"], name: "index_tribes_on_account_status"
    t.index ["confirmation_token"], name: "index_tribes_on_confirmation_token", unique: true
    t.index ["confirmed_at"], name: "index_tribes_on_confirmed_at", where: "(confirmed_at IS NOT NULL)"
    t.index ["country_code", "username"], name: "index_tribes_active_public_by_country", where: "((is_profile_public = true) AND ((account_status)::text = 'active'::text))"
    t.index ["country_code"], name: "index_tribes_on_country_code"
    t.index ["email"], name: "index_tribes_on_email", unique: true
    t.index ["last_password_authenticated_at"], name: "index_tribes_on_last_password_authenticated_at"
    t.index ["paystack_customer_code"], name: "index_tribes_on_paystack_customer_code", unique: true, where: "(paystack_customer_code IS NOT NULL)"
    t.index ["paystack_subaccount_code"], name: "index_tribes_on_paystack_subaccount_code", unique: true, where: "(paystack_subaccount_code IS NOT NULL)"
    t.index ["referred_by_id"], name: "index_tribes_on_referred_by_id"
    t.index ["reset_password_token"], name: "index_tribes_on_reset_password_token", unique: true
    t.index ["role"], name: "index_tribes_on_role"
    t.index ["tip_share_token"], name: "index_tribes_on_tip_share_token", unique: true, where: "(tip_share_token IS NOT NULL)"
    t.index ["unlock_token"], name: "index_tribes_on_unlock_token", unique: true
    t.index ["username"], name: "index_tribes_on_username", unique: true, where: "(username IS NOT NULL)"
    t.index ["widget_embed_token"], name: "index_tribes_on_widget_embed_token", unique: true, where: "(widget_embed_token IS NOT NULL)"
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.string "ip"
    t.uuid "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.text "object_changes"
    t.string "request_id"
    t.string "user_agent"
    t.string "whodunnit"
    t.index ["created_at"], name: "index_versions_on_created_at"
    t.index ["item_type", "item_id", "created_at"], name: "index_versions_on_item_type_item_id_and_created_at"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["request_id"], name: "index_versions_on_request_id"
  end

  add_foreign_key "creator_notifications", "tribes"
  add_foreign_key "early_access_invites", "tribes"
  add_foreign_key "paystack_events", "tips"
  add_foreign_key "paystack_settlements", "paystack_events"
  add_foreign_key "paystack_settlements", "tips"
  add_foreign_key "paystack_settlements", "tribes"
  add_foreign_key "referral_invites", "tribes", column: "referrer_id"
  add_foreign_key "referrals", "tips", column: "qualifying_tip_id"
  add_foreign_key "referrals", "tribes", column: "referred_id"
  add_foreign_key "referrals", "tribes", column: "referrer_id"
  add_foreign_key "tips", "tribes"
  add_foreign_key "tribes", "tribes", column: "referred_by_id"
end

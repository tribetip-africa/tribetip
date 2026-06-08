class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # JWT denylist: every authenticated request looks up jti; must be unique.
    remove_index :jwt_denylists, :jti, if_exists: true
    add_index :jwt_denylists, :jti, unique: true

    # Purge expired revoked tokens without full table scans.
    add_index :jwt_denylists, :exp

    # Future: browse active public creators by market (discover / directory).
    add_index :tribes,
              %i[country_code username],
              name: "index_tribes_active_public_by_country",
              where: "is_profile_public = true AND account_status = 'active'"

    # Payout / KYC gates: tribes ready for verification workflows.
    add_index :tribes,
              :confirmed_at,
              name: "index_tribes_on_confirmed_at",
              where: "confirmed_at IS NOT NULL"

    # Audit history: time-range queries and per-record version timelines.
    add_index :versions, :created_at
    add_index :versions, %i[item_type item_id created_at],
              name: "index_versions_on_item_type_item_id_and_created_at"
  end
end

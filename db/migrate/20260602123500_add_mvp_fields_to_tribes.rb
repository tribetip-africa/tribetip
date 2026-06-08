class AddMvpFieldsToTribes < ActiveRecord::Migration[8.0]
  def change
    add_column :tribes, :username, :string
    add_column :tribes, :display_name, :string
    add_column :tribes, :bio, :text
    add_column :tribes, :country_code, :string, null: false, default: "NG"
    add_column :tribes, :currency, :string, null: false, default: "NGN"
    add_column :tribes, :default_tip_amount_cents, :integer, null: false, default: 50000
    add_column :tribes, :account_status, :string, null: false, default: "pending"
    add_column :tribes, :is_profile_public, :boolean, null: false, default: false
    add_column :tribes, :onboarding_completed_at, :datetime
    add_column :tribes, :terms_accepted_at, :datetime

    add_index :tribes, :username, unique: true, where: "username IS NOT NULL"
    add_index :tribes, :country_code
    add_index :tribes, :account_status
  end
end

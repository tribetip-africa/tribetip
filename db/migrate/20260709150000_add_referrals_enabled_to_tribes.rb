# frozen_string_literal: true

class AddReferralsEnabledToTribes < ActiveRecord::Migration[8.0]
  def change
    add_column :tribes, :referrals_enabled, :boolean, null: false, default: true
  end
end

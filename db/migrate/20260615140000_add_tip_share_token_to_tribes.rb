# frozen_string_literal: true

class AddTipShareTokenToTribes < ActiveRecord::Migration[8.0]
  def change
    add_column :tribes, :tip_share_token, :string
    add_index :tribes, :tip_share_token, unique: true, where: "tip_share_token IS NOT NULL"
  end
end

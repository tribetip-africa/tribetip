# frozen_string_literal: true

class AddRoleToTribes < ActiveRecord::Migration[8.0]
  def change
    add_column :tribes, :role, :string, null: false, default: "creator"
    add_index :tribes, :role
  end
end

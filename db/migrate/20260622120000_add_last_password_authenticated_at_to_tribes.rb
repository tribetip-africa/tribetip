# frozen_string_literal: true

class AddLastPasswordAuthenticatedAtToTribes < ActiveRecord::Migration[8.0]
  def change
    add_column :tribes, :last_password_authenticated_at, :datetime
    add_index :tribes, :last_password_authenticated_at
  end
end

# frozen_string_literal: true

class AddPaidViaToTips < ActiveRecord::Migration[8.0]
  def change
    add_column :tips, :paid_via, :string
    add_index :tips, :paid_via, where: "paid_via IS NOT NULL"
  end
end

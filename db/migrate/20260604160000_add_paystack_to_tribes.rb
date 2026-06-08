# frozen_string_literal: true

class AddPaystackToTribes < ActiveRecord::Migration[8.0]
  def change
    add_column :tribes, :paystack_customer_code, :string
    add_column :tribes, :paystack_subaccount_code, :string

    add_index :tribes, :paystack_customer_code, unique: true, where: "paystack_customer_code IS NOT NULL"
    add_index :tribes, :paystack_subaccount_code, unique: true, where: "paystack_subaccount_code IS NOT NULL"
  end
end

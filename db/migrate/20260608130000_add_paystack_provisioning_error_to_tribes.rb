# frozen_string_literal: true

class AddPaystackProvisioningErrorToTribes < ActiveRecord::Migration[8.0]
  def change
    add_column :tribes, :paystack_provisioning_error, :string
  end
end

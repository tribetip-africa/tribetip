# frozen_string_literal: true

class DefaultTribeMarketToKenya < ActiveRecord::Migration[8.0]
  def change
    change_column_default :tribes, :country_code, from: "NG", to: "KE"
    change_column_default :tribes, :currency, from: "NGN", to: "KES"
  end
end

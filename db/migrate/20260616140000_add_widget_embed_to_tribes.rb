# frozen_string_literal: true

class AddWidgetEmbedToTribes < ActiveRecord::Migration[8.0]
  def change
    change_table :tribes, bulk: true do |t|
      t.string :widget_embed_token
      t.boolean :widget_enabled, null: false, default: false
      t.string :widget_destination_url
      t.string :widget_icon_url
      t.string :widget_accent_color, null: false, default: "#247a45"
      t.string :widget_position, null: false, default: "bottom-right"
      t.string :widget_cta_text, null: false, default: "Tip me"
      t.boolean :widget_open_same_tab, null: false, default: false
    end

    add_index :tribes, :widget_embed_token,
              unique: true,
              where: "widget_embed_token IS NOT NULL",
              name: "index_tribes_on_widget_embed_token"
  end
end

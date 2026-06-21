# frozen_string_literal: true

module Me
  class WidgetEmbedsController < ApplicationController
    before_action :authenticate_tribe!
    before_action :ensure_creator!

    def show
      apply_http_cache_policy(:no_store)

      render json: { widget_embed: widget_embed_payload(current_tribe) }
    end

    def update
      apply_http_cache_policy(:no_store)
      authorize current_tribe, :update?

      if enabling_widget?(widget_embed_params)
        Tribetip::WidgetEmbed.ensure_token!(current_tribe)
      end

      if current_tribe.update(widget_embed_params)
        purge_widget_cache_if_needed
        render json: { widget_embed: widget_embed_payload(current_tribe.reload) }
      else
        render_error(
          Tribetip::Errors::Validation.new(
            "Validation failed.",
            details: { errors: current_tribe.errors.full_messages }
          )
        )
      end
    end

    def rotate
      apply_http_cache_policy(:no_store)
      authorize current_tribe, :update?

      token = Tribetip::WidgetEmbed.rotate!(current_tribe)

      render json: {
        message: "Widget token rotated. Update the embed snippet on your website.",
        widget_embed: widget_embed_payload(current_tribe.reload, token: token)
      }
    end

    private

    def ensure_creator!
      return if current_tribe.creator?

      render_error(
        Tribetip::Errors::BadRequest.new("Website widgets are not available for admin accounts.")
      )
    end

    def widget_embed_params
      params.require(:widget_embed).permit(
        :widget_enabled,
        :widget_destination_url,
        :widget_icon_url,
        :widget_accent_color,
        :widget_position,
        :widget_cta_text,
        :widget_open_same_tab
      )
    end

    def enabling_widget?(permitted)
      permitted.key?(:widget_enabled) && ActiveModel::Type::Boolean.new.cast(permitted[:widget_enabled])
    end

    def purge_widget_cache_if_needed
      return unless current_tribe.widget_embed_token.present?
      return unless current_tribe.saved_change_to_widget_enabled? ||
        current_tribe.saved_change_to_widget_destination_url? ||
        current_tribe.saved_change_to_widget_icon_url? ||
        current_tribe.saved_change_to_widget_accent_color? ||
        current_tribe.saved_change_to_widget_position? ||
        current_tribe.saved_change_to_widget_cta_text? ||
        current_tribe.saved_change_to_widget_open_same_tab?

      Tribetip::WidgetEmbed.purge_config_cache!(current_tribe.widget_embed_token)
    end

    def widget_embed_payload(tribe, token: tribe.widget_embed_token)
      token ||= Tribetip::WidgetEmbed.ensure_token!(tribe) if tribe.widget_enabled?
      destination_url = Tribetip::WidgetEmbed.destination_url_for(tribe)
      active = Tribetip::WidgetEmbed.active?(tribe) && destination_url.present?

      {
        token: token,
        enabled: tribe.widget_enabled?,
        active: active,
        embed_snippet: token.present? ? Tribetip::WidgetEmbed.embed_snippet(token) : nil,
        destination_url: destination_url,
        icon_url: tribe.widget_icon_url,
        accent_color: tribe.widget_accent_color,
        position: Tribetip::WidgetEmbed.normalized_position(tribe.widget_position),
        cta_text: tribe.widget_cta_text,
        open_same_tab: tribe.widget_open_same_tab?,
        config: active ? Tribetip::WidgetEmbed.build_config(tribe) : nil
      }
    end
  end
end

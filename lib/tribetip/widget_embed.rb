# frozen_string_literal: true

module Tribetip
  module WidgetEmbed
    TOKEN_BYTES = 24
    TOKEN_PATTERN = /\A[A-Za-z0-9_-]{20,48}\z/
    POSITIONS = %w[bottom-right bottom-left top-right top-left].freeze
    DEFAULT_ACCENT_COLOR = "#25d366"
    DEFAULT_CTA_TEXT = "Tip me"
    DEFAULT_POSITION = "bottom-right"

    class << self
      def valid_token_format?(value)
        value.to_s.match?(TOKEN_PATTERN)
      end

      def ensure_token!(tribe)
        return tribe.widget_embed_token if tribe.widget_embed_token.present?

        tribe.update!(widget_embed_token: generate_unique_token)
        tribe.widget_embed_token
      end

      def rotate!(tribe)
        previous = tribe.widget_embed_token
        tribe.update!(widget_embed_token: generate_unique_token)
        if previous.present?
          mark_revoked!(previous)
          purge_config_cache!(previous)
        end
        tribe.widget_embed_token
      end

      def resolve_tribe(token)
        return if token.blank?
        return unless valid_token_format?(token)
        return if revoked?(token)

        tribe = Tribe.find_by(widget_embed_token: token)
        return unless tribe
        return unless active?(tribe)

        tribe
      end

      def resolve_config(token)
        tribe = resolve_tribe(token)
        return unless tribe

        Tribetip::SecureCache.fetch(
          cache_key_for(token),
          scope: :public,
          ttl: 60.seconds
        ) do
          build_config(tribe)
        end
      end

      def active?(tribe)
        tribe.widget_enabled? &&
          tribe.creator? &&
          tribe.account_status == "active" &&
          !tribe.suspended?
      end

      def build_config(tribe)
        destination_url = destination_url_for(tribe)
        return if destination_url.blank?

        display_name = tribe.display_name.presence || tribe.username

        {
          app_name: display_name,
          username: tribe.username,
          display_name: display_name,
          bio: tribe.bio,
          country_label: country_label_for(tribe),
          currency: tribe.currency,
          destination_url: destination_url,
          icon_url: tribe.widget_icon_url,
          accent_color: tribe.widget_accent_color.presence || DEFAULT_ACCENT_COLOR,
          position: normalized_position(tribe.widget_position),
          cta_text: button_label_for(tribe),
          tip_presets: TipPresets.labels_for(tribe.default_tip_amount_cents, tribe.currency),
          payment_hint: payment_hint_for(tribe),
          open_same_tab: tribe.widget_open_same_tab?
        }
      end

      def button_label_for(tribe)
        custom = tribe.widget_cta_text.to_s.strip
        return custom unless custom.blank? || custom == DEFAULT_CTA_TEXT

        "Support @#{tribe.username}"
      end

      def country_label_for(tribe)
        meta = Regions::METADATA[tribe.country_code.to_s.upcase]
        return "Creator" unless meta

        "Creator · #{meta[:flag]} #{meta[:name]}"
      end

      def payment_hint_for(tribe)
        meta = Regions::METADATA[tribe.country_code.to_s.upcase]
        meta&.fetch(:payment_hint, nil) || "No account needed · Pay securely online"
      end

      def destination_url_for(tribe)
        custom = tribe.widget_destination_url.to_s.strip
        return custom if custom.present?

        if Tribetip::ShareLinks.shareable?(tribe)
          share_token = Tribetip::ShareLinks.ensure_token!(tribe)
          return "#{Tribetip::Platform.app_url}/t/#{share_token}"
        end

        return Tribetip::Platform.creator_page_url(tribe.username) if tribe.is_profile_public?

        nil
      end

      def embed_snippet(token, api_url: Tribetip::Platform.api_url)
        script_url = "#{Tribetip::Platform.app_url}/widget.js?token=#{token}"
        # data-token is a fallback for platforms (e.g. tag managers, some site
        # builders) that strip the query string or rewrite the script src.
        %(<script src="#{script_url}" data-token="#{token}" data-api="#{api_url}" async></script>)
      end

      def cache_key_for(token)
        "widget_config/#{Digest::SHA256.hexdigest(token.to_s)}"
      end

      def purge_config_cache!(token)
        return if token.blank?

        Tribetip::SecureCache.delete(cache_key_for(token), scope: :public)
      end

      def mark_revoked!(token)
        return if token.blank?

        Tribetip::SecureCache.write(
          revoked_cache_key_for(token),
          true,
          scope: :public,
          ttl: 10.years
        )
      end

      def revoked?(token)
        return false if token.blank?

        Tribetip::SecureCache.read(revoked_cache_key_for(token), scope: :public) == true
      end

      def revoked_cache_key_for(token)
        "widget_revoked/#{Digest::SHA256.hexdigest(token.to_s)}"
      end

      def normalized_position(value)
        position = value.to_s.presence || DEFAULT_POSITION
        POSITIONS.include?(position) ? position : DEFAULT_POSITION
      end

      private

      def generate_unique_token
        loop do
          candidate = SecureRandom.urlsafe_base64(TOKEN_BYTES).tr("=", "")
          break candidate unless token_taken?(candidate)
        end
      end

      def token_taken?(candidate)
        Tribe.exists?(tip_share_token: candidate) ||
          Tribe.exists?(widget_embed_token: candidate)
      end
    end
  end
end

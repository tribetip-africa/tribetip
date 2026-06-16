# frozen_string_literal: true

module Me
  class ShareLinksController < ApplicationController
    before_action :authenticate_tribe!
    before_action :ensure_creator!

    def show
      apply_http_cache_policy(:no_store)
      token = Tribetip::ShareLinks.ensure_token!(current_tribe)
      shareable = Tribetip::ShareLinks.shareable?(current_tribe.reload)

      render json: {
        share_link: share_link_payload(token, shareable: shareable)
      }
    end

    def rotate
      apply_http_cache_policy(:no_store)
      authorize current_tribe, :update?

      token = Tribetip::ShareLinks.rotate!(current_tribe)
      shareable = Tribetip::ShareLinks.shareable?(current_tribe.reload)

      render json: {
        message: "Share link rotated. Previous QR codes no longer work.",
        share_link: share_link_payload(token, shareable: shareable)
      }
    end

    private

    def ensure_creator!
      return if current_tribe.creator?

      render_error(
        Tribetip::Errors::BadRequest.new("Share links are not available for admin accounts.")
      )
    end

    def share_link_payload(token, shareable:)
      path = share_path(token)
      {
        token: token,
        path: path,
        url: shareable ? "#{Tribetip::Platform.app_url}#{path}" : nil,
        shareable: shareable
      }
    end

    def share_path(token)
      "/t/#{token}"
    end
  end
end

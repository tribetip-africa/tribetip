# frozen_string_literal: true

module Me
  class NotificationsController < ApplicationController
    before_action :authenticate_tribe!
    before_action :authorize_notification_access!

    def index
      apply_http_cache_policy(:no_store)
      notifications = current_tribe.creator_notifications.recent_first.limit(limit_param)

      render json: {
        notifications: notifications.map(&:as_json),
        unread_count: current_tribe.creator_notifications.unread.count
      }
    end

    def read
      apply_http_cache_policy(:no_store)
      notification = current_tribe.creator_notifications.find(params[:id])
      notification.mark_read!

      render json: { notification: notification.as_json }
    end

    def read_all
      apply_http_cache_policy(:no_store)
      current_tribe.creator_notifications.unread.update_all(read_at: Time.current)

      render json: { unread_count: 0 }
    end

    private

    def authorize_notification_access!
      authorize current_tribe, :access_notifications?
    end

    def limit_param
      [ params.fetch(:limit, 20).to_i, 50 ].min.clamp(1, 50)
    end
  end
end

# frozen_string_literal: true

module Tribetip
  module PublicSitemap
    PER_PAGE_MAX = 500
    PER_PAGE_DEFAULT = 500

    class << self
      def list(page:, per_page:)
        page = [ page.to_i, 1 ].max
        per_page = per_page.to_i.clamp(1, PER_PAGE_MAX)
        scope = shareable_scope
        total_count = scope.count
        total_pages = [ (total_count.to_f / per_page).ceil, 1 ].max
        page = [ page, total_pages ].min

        creators = scope
                   .order(updated_at: :desc, username: :asc)
                   .offset((page - 1) * per_page)
                   .limit(per_page)
                   .pluck(:username, :updated_at)
                   .map do |username, updated_at|
          {
            username: username,
            updated_at: updated_at.iso8601
          }
        end

        {
          creators: creators,
          page: page,
          per_page: per_page,
          total_pages: total_pages,
          total_count: total_count
        }
      end

      private

      def shareable_scope
        Tribe.where(role: "creator", is_profile_public: true, account_status: "active")
      end
    end
  end
end

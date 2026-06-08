# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    include AdminAuditable

    before_action :authenticate_tribe!
    before_action :require_admin!

    private

    def require_admin!
      return if current_tribe&.admin?

      render_error(Tribetip::Errors::Authorization.new)
    end
  end
end

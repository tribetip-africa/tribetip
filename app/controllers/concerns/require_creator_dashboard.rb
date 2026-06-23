# frozen_string_literal: true

module RequireCreatorDashboard
  extend ActiveSupport::Concern

  included do
    before_action :require_dashboard_access!
  end

  private

  def require_dashboard_access!
    authorize current_tribe, :access_dashboard?
  end
end

class ApplicationController < ActionController::API
  include PaperTrail::Rails::Controller
  before_action :set_paper_trail_whodunnit

  private

  # Devise integrates through current_user when available.
  def user_for_paper_trail
    return current_user.id if respond_to?(:current_user, true) && current_user.present?

    "system"
  end

  def info_for_paper_trail
    {
      request_id: request.request_id,
      ip: request.remote_ip,
      user_agent: request.user_agent
    }
  end
end

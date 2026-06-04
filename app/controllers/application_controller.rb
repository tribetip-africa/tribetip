class ApplicationController < ActionController::API
  include DatabaseRouting
  include SecureHttpCaching
  include Tribetip::Errors::Handler
  include PaperTrail::Rails::Controller
  before_action :set_paper_trail_whodunnit

  private

  def user_for_paper_trail
    return current_tribe.id if respond_to?(:current_tribe, true) && current_tribe.present?

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

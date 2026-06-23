# frozen_string_literal: true

module Authorization
  extend ActiveSupport::Concern
  include ::Pundit::Authorization

  included do
    rescue_from ::Pundit::NotAuthorizedError, with: :render_authorization_error
  end

  private

  def pundit_user
    @pundit_user ||= Tribetip::Authorization::Context.new(
      subject: current_tribe,
      environment: authorization_environment
    )
  end

  def authorization_environment
    {
      ip: request.remote_ip,
      path: request.path
    }
  end

  def render_authorization_error(exception)
    render_error(Tribetip::Authorization.error_for(exception))
  end
end

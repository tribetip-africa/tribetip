# frozen_string_literal: true

module Authorization
  extend ActiveSupport::Concern
  include ::Pundit::Authorization

  included do
    rescue_from ::Pundit::NotAuthorizedError, with: :render_authorization_error
  end

  private

  def pundit_user
    current_tribe
  end

  def render_authorization_error(_exception = nil)
    render_error(Tribetip::Errors::Authorization.new)
  end
end

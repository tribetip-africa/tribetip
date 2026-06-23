# frozen_string_literal: true

module RequiresFreshPasswordSession
  extend ActiveSupport::Concern

  class_methods do
    def require_fresh_password_session!(**options)
      before_action :ensure_fresh_password_session!, **options
    end
  end

  private

  def ensure_fresh_password_session!
    return if Tribetip::Security::FreshSession.satisfied_by?(current_tribe)

    render_error(Tribetip::Errors::ReauthenticationRequired.new)
  end
end

# frozen_string_literal: true

module AdminAuditable
  extend ActiveSupport::Concern

  private

  def record_admin_audit!(action:, target:, details: {})
    Tribetip::Audit::RecordAdminAction.call(
      admin: current_tribe,
      action: action,
      target: target,
      details: details,
      request: request
    )
  end
end

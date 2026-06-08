# frozen_string_literal: true

module AuditRequestContext
  extend ActiveSupport::Concern

  private

  def audit_request_context
    Tribetip::Audit::RecordTipEvent::RequestContext.new(
      request_id: request.request_id,
      ip: request.remote_ip
    )
  end
end

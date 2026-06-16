# frozen_string_literal: true

module Idempotable
  extend ActiveSupport::Concern

  private

  def idempotency_key_header
    request.headers["Idempotency-Key"].to_s.strip.presence
  end
end

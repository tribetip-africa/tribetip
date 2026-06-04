# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Errors do
  describe Tribetip::Errors::Base do
    it "exposes code, message, details, and http status" do
      error = described_class.new(
        "Custom message",
        code: "custom_code",
        http_status: :teapot,
        details: { field: "email" }
      )

      expect(error.message).to eq("Custom message")
      expect(error.code).to eq("custom_code")
      expect(error.http_status).to eq(:teapot)
      expect(error.details).to eq({ field: "email" })
    end

    it "serializes to a hash without empty details" do
      error = described_class.new("Oops", code: "oops", details: {})
      expect(error.to_h).to eq({ code: "oops", message: "Oops" })
    end
  end

  {
    Tribetip::Errors::Validation => [:validation_failed, :unprocessable_content],
    Tribetip::Errors::Authentication => [:authentication_failed, :unauthorized],
    Tribetip::Errors::Authorization => [:forbidden, :forbidden],
    Tribetip::Errors::NotFound => [:not_found, :not_found],
    Tribetip::Errors::RateLimit => [:rate_limited, :too_many_requests],
    Tribetip::Errors::BadRequest => [:bad_request, :bad_request],
    Tribetip::Errors::Internal => [:internal_error, :internal_server_error]
  }.each do |klass, (code, status)|
    it "#{klass} defaults to #{code} / #{status}" do
      error = klass.new

      expect(error.code).to eq(code.to_s)
      expect(error.http_status).to eq(status)
      expect(error.message).to be_present
    end
  end
end

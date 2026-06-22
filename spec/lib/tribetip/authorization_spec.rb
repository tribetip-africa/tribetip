# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Authorization do
  describe ".error_for" do
    it "maps dashboard access failures to onboarding required" do
      error = described_class.error_for(instance_double(Pundit::NotAuthorizedError, query: :access_dashboard?))

      expect(error).to be_a(Tribetip::Errors::OnboardingRequired)
    end

    it "maps creator-only feature failures to bad request" do
      error = described_class.error_for(instance_double(Pundit::NotAuthorizedError, query: :manage_widget?))

      expect(error).to be_a(Tribetip::Errors::BadRequest)
      expect(error.message).to include("admin accounts")
    end

    it "falls back to generic authorization errors" do
      error = described_class.error_for(instance_double(Pundit::NotAuthorizedError, query: :update?))

      expect(error).to be_a(Tribetip::Errors::Authorization)
    end
  end
end

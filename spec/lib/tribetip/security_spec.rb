# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Security do
  describe ".require_email_confirmation?" do
    it "defaults to false outside production" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))

      with_env("TRIBETIP_REQUIRE_EMAIL_CONFIRMATION" => nil) do
        expect(described_class.require_email_confirmation?).to be(false)
      end
    end

    it "defaults to true in production" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))

      with_env("TRIBETIP_REQUIRE_EMAIL_CONFIRMATION" => nil) do
        expect(described_class.require_email_confirmation?).to be(true)
      end
    end
  end

  def with_env(vars)
    previous = vars.keys.index_with { |key| ENV[key] }
    vars.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end

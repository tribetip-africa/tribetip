# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::SecureCache do
  around do |example|
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache.lookup_store(:memory_store)
    example.run
  ensure
    Rails.cache = original_cache
  end

  describe ".fetch" do
    it "stores and returns values for public keys" do
      result = described_class.fetch("public_profile/demo_user", scope: :public) { { username: "demo_user" } }

      expect(result).to eq(username: "demo_user")
      expect(described_class.read("public_profile/demo_user", scope: :public)).to eq(username: "demo_user")
    end

    it "rejects sensitive cache keys" do
      expect {
        described_class.fetch("tribe/session_token", scope: :public) { "secret" }
      }.to raise_error(described_class::SecurityError)
    end
  end

  describe ".bump_version!" do
    it "invalidates prior public cache entries" do
      described_class.fetch("public_profile/versioned", scope: :public) { "v1" }
      described_class.bump_version!(:public)

      expect(described_class.fetch("public_profile/versioned", scope: :public) { "v2" }).to eq("v2")
    end
  end
end

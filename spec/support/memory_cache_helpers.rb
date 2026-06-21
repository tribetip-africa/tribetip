# frozen_string_literal: true

RSpec.shared_context "with memory cache" do
  around do |example|
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache.lookup_store(:memory_store)
    example.run
  ensure
    Rails.cache = original_cache
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::WidgetEmbed do
  around do |example|
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache.lookup_store(:memory_store)
    example.run
  ensure
    Rails.cache = original_cache
  end

  def create_creator(username: "widget_creator")
    tribe = Tribe.new(
      email: "#{username}@tribetip.africa",
      password: "securepass123",
      password_confirmation: "securepass123",
      username: username,
      display_name: "Widget Creator",
      is_profile_public: true,
      account_status: "active",
      widget_enabled: true
    )
    tribe.skip_confirmation!
    tribe.save!
    tribe
  end

  it "generates a unique opaque token" do
    tribe = create_creator

    token = described_class.ensure_token!(tribe)

    expect(token).to be_present
    expect(token).not_to include(tribe.username)
    expect(described_class.valid_token_format?(token)).to be(true)
  end

  it "rotates tokens and purges the previous widget cache entry" do
    tribe = create_creator
    original = described_class.ensure_token!(tribe)
    Tribetip::SecureCache.write(
      described_class.cache_key_for(original),
      { app_name: "Cached" },
      scope: :public
    )

    rotated = described_class.rotate!(tribe)

    expect(rotated).not_to eq(original)
    expect(described_class.revoked?(original)).to be(true)
    expect(Tribetip::SecureCache.read(described_class.cache_key_for(original), scope: :public)).to be_nil
    expect(described_class.resolve_tribe(original)).to be_nil
    expect(described_class.resolve_tribe(rotated)).to eq(tribe)
  end

  it "does not resolve disabled widgets" do
    tribe = create_creator(username: "widget_disabled")
    token = described_class.ensure_token!(tribe)
    tribe.update!(widget_enabled: false)

    expect(described_class.resolve_tribe(token)).to be_nil
  end
end

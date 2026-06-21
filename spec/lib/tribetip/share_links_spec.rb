# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::ShareLinks do
  include_context "with memory cache"

  it "generates a unique opaque token" do
    tribe = create_creator

    token = described_class.ensure_token!(tribe)

    expect(token).to be_present
    expect(token).not_to include(tribe.username)
    expect(described_class.valid_token_format?(token)).to be(true)
  end

  it "rotates tokens and purges the previous share cache entry" do
    tribe = create_creator
    original = described_class.ensure_token!(tribe)
    Tribetip::SecureCache.write(
      described_class.cache_key_for(original),
      { display_name: "Cached" },
      scope: :public
    )

    rotated = described_class.rotate!(tribe)

    expect(rotated).not_to eq(original)
    expect(described_class.revoked?(original)).to be(true)
    expect(Tribetip::SecureCache.read(described_class.cache_key_for(original), scope: :public)).to be_nil
    expect(described_class.resolve_profile(original)).to be_nil
    expect(described_class.resolve_profile(rotated)).to eq(tribe)
  end

  it "does not resolve unpublished profiles" do
    tribe = create_creator(username: "share_private")
    token = described_class.ensure_token!(tribe)
    tribe.update!(is_profile_public: false)

    expect(described_class.resolve_profile(token)).to be_nil
  end
end

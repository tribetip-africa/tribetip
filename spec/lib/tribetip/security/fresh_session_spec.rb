# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Security::FreshSession do
  it "requires a recent password authentication timestamp" do
    tribe = create_onboarded_tribe(username: "fresh_session_recent")
    tribe.update!(last_password_authenticated_at: 5.minutes.ago)

    expect(described_class.satisfied_by?(tribe)).to be(true)
  end

  it "rejects stale password authentication timestamps" do
    tribe = create_onboarded_tribe(username: "fresh_session_stale")
    tribe.update!(last_password_authenticated_at: 20.minutes.ago)

    expect(described_class.satisfied_by?(tribe)).to be(false)
  end
end

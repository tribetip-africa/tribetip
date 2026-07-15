# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Launch do
  around do |example|
    previous = ENV["TRIBETIP_LAUNCH_MODE"]
    example.run
  ensure
    if previous.nil?
      ENV.delete("TRIBETIP_LAUNCH_MODE")
    else
      ENV["TRIBETIP_LAUNCH_MODE"] = previous
    end
  end

  it "defaults to open" do
    ENV.delete("TRIBETIP_LAUNCH_MODE")
    expect(described_class.mode).to eq("open")
    expect(described_class.signup_gated?).to be(false)
  end

  it "gates signup for waitlist and coming_soon" do
    ENV["TRIBETIP_LAUNCH_MODE"] = "waitlist"
    expect(described_class.signup_gated?).to be(true)

    ENV["TRIBETIP_LAUNCH_MODE"] = "coming_soon"
    expect(described_class.signup_gated?).to be(true)
  end
end

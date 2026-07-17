# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::TipLimits do
  around do |example|
    previous_min = ENV["TRIBETIP_TIP_MIN_CENTS"]
    previous_max = ENV["TRIBETIP_TIP_MAX_CENTS"]
    example.run
  ensure
    ENV["TRIBETIP_TIP_MIN_CENTS"] = previous_min
    ENV["TRIBETIP_TIP_MAX_CENTS"] = previous_max
  end

  it "defaults to 100..10_000_000 cents" do
    ENV.delete("TRIBETIP_TIP_MIN_CENTS")
    ENV.delete("TRIBETIP_TIP_MAX_CENTS")

    expect(described_class.min_cents).to eq(100)
    expect(described_class.max_cents).to eq(10_000_000)
    expect(described_class.within_limits?(100)).to be(true)
    expect(described_class.within_limits?(99)).to be(false)
    expect(described_class.within_limits?(10_000_001)).to be(false)
  end

  it "reads bounds from the environment" do
    ENV["TRIBETIP_TIP_MIN_CENTS"] = "500"
    ENV["TRIBETIP_TIP_MAX_CENTS"] = "2500"

    expect(described_class.min_cents).to eq(500)
    expect(described_class.max_cents).to eq(2500)
    expect(described_class.within_limits?(500)).to be(true)
    expect(described_class.within_limits?(2500)).to be(true)
    expect(described_class.within_limits?(499)).to be(false)
  end
end

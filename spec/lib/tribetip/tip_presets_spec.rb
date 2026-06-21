# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::TipPresets do
  it "builds standard, generous, and custom labels" do
    labels = described_class.labels_for(50_000, "NGN")

    expect(labels).to eq([ "₦500", "₦1,000", "Custom" ])
  end
end

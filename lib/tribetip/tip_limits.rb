# frozen_string_literal: true

module Tribetip
  # Bounds for public tip checkout amounts (minor units / "cents").
  module TipLimits
    module_function

    DEFAULT_MIN_CENTS = 100 # 1.00 in major units
    DEFAULT_MAX_CENTS = 10_000_000 # 100_000.00 in major units

    def min_cents
      value = ENV.fetch("TRIBETIP_TIP_MIN_CENTS", DEFAULT_MIN_CENTS.to_s).to_i
      value.positive? ? value : DEFAULT_MIN_CENTS
    end

    def max_cents
      value = ENV.fetch("TRIBETIP_TIP_MAX_CENTS", DEFAULT_MAX_CENTS.to_s).to_i
      value >= min_cents ? value : DEFAULT_MAX_CENTS
    end

    def within_limits?(amount_cents)
      cents = amount_cents.to_i
      cents >= min_cents && cents <= max_cents
    end
  end
end

# frozen_string_literal: true

module Tribetip
  module Launch
    MODES = %w[open waitlist coming_soon].freeze

    module_function

    def mode
      raw = ENV["TRIBETIP_LAUNCH_MODE"].to_s.strip.downcase
      return raw if MODES.include?(raw)

      "open"
    end

    def signup_gated?
      mode != "open"
    end
  end
end

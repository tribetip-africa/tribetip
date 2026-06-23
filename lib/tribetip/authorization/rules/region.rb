# frozen_string_literal: true

module Tribetip
  module Authorization
    module Rules
      module Region
        module_function

        def market_live?(country_code)
          Regions.enabled?(country_code.to_s.upcase)
        end
      end
    end
  end
end

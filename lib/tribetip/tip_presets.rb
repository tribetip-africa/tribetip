# frozen_string_literal: true

module Tribetip
  module TipPresets
    module_function

    def labels_for(default_cents, currency)
      standard = [default_cents.to_i, 100].max
      generous = [standard + 100, standard * 2].max

      [
        MoneyFormat.format_cents(standard, currency),
        MoneyFormat.format_cents(generous, currency),
        "Custom"
      ]
    end
  end
end

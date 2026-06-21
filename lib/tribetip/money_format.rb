# frozen_string_literal: true

module Tribetip
  module MoneyFormat
    module_function

    def format_cents(cents, currency)
      units = cents.to_i / 100.0
      precision = units == units.to_i ? 0 : 2
      formatted =
        if precision.zero?
          ActiveSupport::NumberHelper.number_to_delimited(units.to_i)
        else
          format("%.#{precision}f", units)
        end

      "#{currency_prefix(currency)}#{formatted}"
    end

    def currency_prefix(currency)
      case currency.to_s.upcase
      when "KES" then "KSh "
      when "NGN" then "₦"
      when "GHS" then "GH₵"
      when "ZAR" then "R "
      when "XOF" then "CFA "
      else "#{currency} "
      end
    end
  end
end

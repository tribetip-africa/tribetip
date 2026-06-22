# frozen_string_literal: true

class PaymentAlertPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.admin?

      scope.all
    end
  end

  def index?
    admin?
  end
end

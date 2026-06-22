# frozen_string_literal: true

class PaystackEventPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.admin?

      scope.all
    end
  end

  def index?
    admin?
  end

  def replay?
    admin?
  end
end

# frozen_string_literal: true

class EarlyAccessInvitePolicy < ApplicationPolicy
  def index?
    admin?
  end

  def create?
    admin?
  end

  def revoke?
    admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.admin?

      scope.all
    end
  end
end

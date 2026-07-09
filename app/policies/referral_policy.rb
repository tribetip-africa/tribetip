# frozen_string_literal: true

class ReferralPolicy < ApplicationPolicy
  def index?
    admin?
  end

  def reject?
    admin? && !record.rewarded? && !record.rejected?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.admin?

      scope.all
    end
  end
end

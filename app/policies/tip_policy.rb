# frozen_string_literal: true

class TipPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      if user.admin?
        scope.all
      else
        scope.where(tribe_id: user.id)
      end
    end
  end

  def show?
    owner? || admin?
  end

  private

  def owner?
    user.present? && record.tribe_id == user.id
  end
end

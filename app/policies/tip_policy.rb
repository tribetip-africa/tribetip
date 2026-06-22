# frozen_string_literal: true

class TipPolicy < ApplicationPolicy
  include Tribetip::Authorization::Rules::Account

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
    owner_of_tip?(context) || admin?
  end

  def reconcile?
    owner_of_tip?(context) && record.pending?
  end
end

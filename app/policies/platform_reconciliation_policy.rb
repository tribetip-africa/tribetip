# frozen_string_literal: true

class PlatformReconciliationPolicy < ApplicationPolicy
  def show?
    admin?
  end

  def create?
    admin?
  end
end

# frozen_string_literal: true

class TribePolicy < ApplicationPolicy
  def show?
    owner? || admin?
  end

  def update?
    owner? && !record.suspended?
  end

  def publish?
    owner? &&
      record.creator? &&
      !record.suspended? &&
      record.account_status == "active" &&
      record.display_name.present? &&
      record.paystack_onboarding_complete?
  end

  def suspend?
    admin? && user.id != record.id && !record.suspended?
  end

  def activate?
    admin? && user.id != record.id && record.suspended?
  end

  def audit_paystack?
    admin?
  end

  private

  def owner?
    user.present? && user.id == record.id
  end
end

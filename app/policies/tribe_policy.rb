# frozen_string_literal: true

class TribePolicy < ApplicationPolicy
  include Tribetip::Authorization::Rules::Account
  include Tribetip::Authorization::Rules::Paystack
  include Tribetip::Authorization::Rules::Region

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.admin?

      scope.all
    end
  end

  def index?
    admin?
  end

  def show?
    owner?(context) || admin?
  end

  def update?
    owner?(context) && !context.suspended?
  end

  def publish?
    owner?(context) &&
      context.creator? &&
      active_account?(context) &&
      payout_ready?(record) &&
      record.display_name.present?
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

  def access_dashboard?
    dashboard_access?(context)
  end

  def manage_widget?
    creator_only?(context)
  end

  def manage_share_link?
    creator_only?(context)
  end

  def access_notifications?
    creator_only?(context)
  end

  def access_paystack_onboarding?
    creator_only?(context)
  end

  def access_paystack_withdrawals?
    creator_only?(context)
  end

  def access_paystack_settlements?
    creator_only?(context)
  end

  def access_paystack_repair?
    creator_only?(context)
  end
end

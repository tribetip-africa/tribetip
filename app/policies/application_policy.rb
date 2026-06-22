# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :context, :user, :record

  def initialize(user, record)
    @record = record
    @context = build_context(user, record)
    @user = @context.subject
  end

  def admin?
    context.admin?
  end

  class Scope
    attr_reader :context, :user, :scope

    def initialize(user, scope)
      @scope = scope
      @context = user.is_a?(Tribetip::Authorization::Context) ? user : Tribetip::Authorization::Context.new(subject: user)
      @user = @context.subject
    end

    def resolve
      scope.all
    end
  end

  private

  def build_context(user, record)
    if user.is_a?(Tribetip::Authorization::Context)
      user.with(resource: record)
    else
      Tribetip::Authorization::Context.new(subject: user, resource: record)
    end
  end
end

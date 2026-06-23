# frozen_string_literal: true

module Tribetip
  module Authorization
    module Rules
      module Account
        module_function

        def creator_only?(ctx)
          ctx.subject&.creator?
        end

        def active_account?(ctx)
          ctx.subject.present? &&
            ctx.subject.account_status == "active" &&
            !ctx.subject.suspended?
        end

        def owner?(ctx)
          ctx.subject.present? &&
            ctx.resource.present? &&
            ctx.subject.id == ctx.resource.id
        end

        def owner_of_tip?(ctx)
          ctx.subject.present? &&
            ctx.resource.present? &&
            ctx.subject.id == ctx.resource.tribe_id
        end
      end
    end
  end
end

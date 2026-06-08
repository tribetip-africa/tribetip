class ApplicationJob < ActiveJob::Base
  include Tribetip::Errors::JobHelpers

  around_perform :with_paper_trail_context

  private

  def with_paper_trail_context
    PaperTrail.request(whodunnit: "job:#{self.class.name}") do
      yield
    end
  end
end

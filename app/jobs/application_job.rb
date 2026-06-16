class ApplicationJob < ActiveJob::Base
  include Tribetip::Errors::JobHelpers

  # Avoid jobs enqueued inside DB transactions running before commit (e.g. withdrawals).
  self.enqueue_after_transaction_commit = true

  around_perform :with_paper_trail_context

  private

  def with_paper_trail_context
    PaperTrail.request(whodunnit: "job:#{self.class.name}") do
      yield
    end
  end
end

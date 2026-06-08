# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Errors::JobHelpers do
  let(:runner) do
    Class.new do
      include Tribetip::Errors::JobHelpers

      attr_reader :result, :raised

      def run!(fail_with: nil)
        @result = run_job_step(action: "sync") do
          case fail_with
          when :tribetip then raise Tribetip::Errors::Validation.new("Invalid payload")
          when :standard then raise StandardError, "boom"
          else
            :ok
          end
        end
      rescue Tribetip::Errors::Base => e
        @raised = e
      end
    end.new
  end

  it "returns the block result on success" do
    runner.run!
    expect(runner.result).to eq(:ok)
    expect(runner.raised).to be_nil
  end

  it "re-raises Tribetip errors without wrapping" do
    runner.run!(fail_with: :tribetip)
    expect(runner.raised).to be_a(Tribetip::Errors::Validation)
    expect(runner.raised.code).to eq("validation_failed")
  end

  it "wraps unexpected errors as internal errors" do
    runner.run!(fail_with: :standard)
    expect(runner.raised).to be_a(Tribetip::Errors::Internal)
    expect(runner.raised.cause).to be_a(StandardError)
  end
end

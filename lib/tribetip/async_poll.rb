# frozen_string_literal: true

module Tribetip
  module AsyncPoll
    module_function

    def wait_until(max: 25.seconds, interval: 0.1.seconds)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + max.to_f
      loop do
        value = yield
        return value if value

        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep interval.to_f
      end

      nil
    end
  end
end

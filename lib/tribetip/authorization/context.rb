# frozen_string_literal: true

module Tribetip
  module Authorization
    class Context
      attr_reader :subject, :resource, :environment

      def initialize(subject: nil, resource: nil, environment: {})
        @subject = subject
        @resource = resource
        @environment = environment
      end

      def with(resource:)
        self.class.new(subject: subject, resource: resource, environment: environment)
      end

      def admin?
        subject&.admin?
      end

      def creator?
        subject&.creator?
      end

      def suspended?
        subject&.suspended?
      end

      def region_enabled?
        return false unless subject&.country_code

        Regions.enabled?(subject.country_code)
      end
    end
  end
end

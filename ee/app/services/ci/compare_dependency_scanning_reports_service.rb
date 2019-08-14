# frozen_string_literal: true

module Ci
  class CompareDependencyScanningReportsService < ::Ci::CompareReportsBaseService
    def comparer_class
      Gitlab::Ci::Reports::Security::VulnerabilityReportsComparer
    end

    def serializer_class
      Vulnerabilities::OccurrenceDiffSerializer
    end

    def get_report(pipeline)
      report = pipeline&.security_reports&.get_report('dependency_scanning')

      raise report.error if report&.errored? # propagate error to base class's execute method

      report
    end
  end
end

# frozen_string_literal: true

module Ci
  # The purpose of this class is to store Build related data that can be disposed.
  # Data that should be persisted forever, should be stored with Ci::Build model.
  class BuildMetadata < ApplicationRecord
    BuildTimeout = Struct.new(:value, :source)

    extend Gitlab::Ci::Model
    include Presentable
    include ChronicDurationAttribute
    include Gitlab::Utils::StrongMemoize

    self.table_name = 'ci_builds_metadata'

    belongs_to :build, class_name: 'CommitStatus'
    belongs_to :project

    before_create :set_build_project

    validates :build, presence: true

    serialize :config_options, Serializers::JSON # rubocop:disable Cop/ActiveRecordSerialize
    serialize :config_variables, Serializers::JSON # rubocop:disable Cop/ActiveRecordSerialize

    chronic_duration_attr_reader :timeout_human_readable, :timeout

    enum timeout_source: {
        unknown_timeout_source: 1,
        project_timeout_source: 2,
        runner_timeout_source: 3,
        job_timeout_source: 4
    }

    def update_timeout_state
      return unless build.runner.present? || build.timeout.present?

      timeout = timeout_with_highest_precedence

      update(timeout: timeout.value, timeout_source: timeout.source)
    end

    private

    def set_build_project
      self.project_id ||= self.build.project_id
    end

    def timeout_with_highest_precedence
      [(job_timeout || project_timeout), runner_timeout].compact.min_by { |timeout| timeout.value }
    end

    def project_timeout
      strong_memoize(:project_timeout) do
        BuildTimeout.new(project&.build_timeout, :project_timeout_source)
      end
    end

    def job_timeout
      strong_memoize(:job_timeout) do
        BuildTimeout.new(build.timeout, :job_timeout_source) if build.timeout
      end
    end

    def runner_timeout
      strong_memoize(:runner_timeout) do
        BuildTimeout.new(build.runner.maximum_timeout, :runner_timeout_source) if runner_timeout_set?
      end
    end

    def runner_timeout_set?
      build.runner&.maximum_timeout.to_i > 0
    end
  end
end

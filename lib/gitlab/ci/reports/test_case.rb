# frozen_string_literal: true

module Gitlab
  module Ci
    module Reports
      class TestCase
        STATUS_SUCCESS = 'success'
        STATUS_FAILED = 'failed'
        STATUS_SKIPPED = 'skipped'
        STATUS_ERROR = 'error'
        STATUS_TYPES = [STATUS_SUCCESS, STATUS_FAILED, STATUS_SKIPPED, STATUS_ERROR].freeze

        attr_reader :name, :classname, :execution_time, :status, :file, :system_output, :stack_trace, :key, :attachment, :job

        # rubocop: disable Metrics/ParameterLists
        def initialize(name:, classname:, execution_time:, status:, file: nil, system_output: nil, stack_trace: nil, attachment: nil, job: nil)
          @name = name
          @classname = classname
          @file = file
          @execution_time = execution_time.to_f
          @status = status
          @system_output = system_output
          @stack_trace = stack_trace
          @key = sanitize_key_name("#{classname}_#{name}")
          @attachment = attachment
          @job = job
        end
        # rubocop: enable Metrics/ParameterLists

        def has_attachment?
          attachment.present?
        end

        def attachment_url
          return unless has_attachment?

          Rails.application.routes.url_helpers.file_project_job_artifacts_path(
            job.project,
            job.id,
            attachment
          )
        end

        private

        def sanitize_key_name(key)
          key.gsub(/[^0-9A-Za-z]/, '-')
        end
      end
    end
  end
end

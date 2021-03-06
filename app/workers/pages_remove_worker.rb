# frozen_string_literal: true

# TODO: remove this worker https://gitlab.com/gitlab-org/gitlab/-/issues/340641
class PagesRemoveWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker

  data_consistency :always

  sidekiq_options retry: 3
  feature_category :pages
  loggable_arguments 0

  def perform(project_id)
    # no-op
  end
end

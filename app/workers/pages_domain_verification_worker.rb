# frozen_string_literal: true

class PagesDomainVerificationWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker

  data_consistency :always

  sidekiq_options retry: 3

  feature_category :pages

  # rubocop: disable CodeReuse/ActiveRecord
  def perform(domain_id)
    return if Gitlab::Database.read_only?

    domain = PagesDomain.find_by(id: domain_id)

    return unless domain

    VerifyPagesDomainService.new(domain).execute
  end
  # rubocop: enable CodeReuse/ActiveRecord
end

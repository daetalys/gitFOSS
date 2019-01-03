# frozen_string_literal: true

class Release < ActiveRecord::Base
  include CacheMarkdownField
  include Gitlab::Utils::StrongMemoize

  cache_markdown_field :description

  belongs_to :project
  # releases prior to 11.7 have no author
  belongs_to :author, class_name: 'User'

  has_many :links, class_name: 'Releases::Link'

  accepts_nested_attributes_for :links, allow_destroy: true

  validates :description, :project, :tag, presence: true

  ##
  # There are several projects which have been violating this rule on gitlab.com.
  # We should not create such duplicate rows anymore.
  validates :tag, uniqueness: { scope: :project }, on: :create

  validates :sha, presence: true, on: :create
  validates :name, presence: true

  scope :sorted, -> { order(created_at: :desc) }

  delegate :repository, to: :project

  def commit
    strong_memoize(:commit) do
      repository.commit(actual_sha)
    end
  end

  def tag_missing?
    actual_tag.nil?
  end

  def assets_count
    links.count + sources.count
  end

  def sources
    strong_memoize(:sources) do
      Releases::Source.all(project, tag)
    end
  end

  private

  def actual_sha
    sha || actual_tag&.dereferenced_target
  end

  def actual_tag
    strong_memoize(:actual_tag) do
      repository.find_tag(tag)
    end
  end
end

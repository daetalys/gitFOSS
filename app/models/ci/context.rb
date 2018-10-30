# frozen_string_literal: true

module Ci
  class Context < ActiveRecord::Base
    extend Gitlab::Ci::Model
    include Ci::Contextable

    belongs_to :project
  end
end

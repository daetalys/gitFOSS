# frozen_string_literal: true

module Gitlab
  module Database
    module Migrations
      module Observers
        def self.all_observers
          [
            TotalDatabaseSizeChange,
            QueryStatistics,
            QueryLog,
            QueryDetails
          ]
        end
      end
    end
  end
end

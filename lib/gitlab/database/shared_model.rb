# frozen_string_literal: true

module Gitlab
  module Database
    # This abstract class is used for models which need to exist in multiple de-composed databases.
    class SharedModel < ActiveRecord::Base
      self.abstract_class = true

      class << self
        def using_connection(connection)
          raise 'cannot nest connection overrides for shared models' unless overriding_connection.nil?

          self.overriding_connection = connection

          yield
        ensure
          self.overriding_connection = nil
        end

        def connection
          if connection = self.overriding_connection
            connection
          else
            super
          end
        end

        private

        def overriding_connection
          Thread.current[:overriding_connection]
        end

        def overriding_connection=(connection)
          Thread.current[:overriding_connection] = connection
        end
      end
    end
  end
end

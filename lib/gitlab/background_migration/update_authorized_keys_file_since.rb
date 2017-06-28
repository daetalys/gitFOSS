module Gitlab
  module BackgroundMigration
    class UpdateAuthorizedKeysFileSince
      class Key < ActiveRecord::Base
        self.table_name = 'keys'

        def shell_id
          "key-#{id}"
        end
      end

      def perform(cutoff_datetime)
        add_keys_since(cutoff_datetime)

        remove_keys_not_found_in_db
      end

      def add_keys_since(cutoff_datetime)
        start_key = Key.select(:id).where("created_at >= ?", cutoff_datetime).take
        if start_key
          batch_add_keys_in_db_starting_from(start_key.id)
        end
      end

      def remove_keys_not_found_in_db
        GitlabShellWorker.perform_async(:remove_keys_not_found_in_db)
      end

      # Not added to Gitlab::Shell because I don't expect this to be used again
      def batch_add_keys_in_db_starting_from(start_id)
        gitlab_shell.batch_add_keys do |adder|
          Key.find_each(start: start_id, batch_size: 1000) do |key|
            adder.add_key(key.shell_id, key.key)
          end
        end
      end

      def gitlab_shell
        @gitlab_shell ||= Gitlab::Shell.new
      end
    end
  end
end

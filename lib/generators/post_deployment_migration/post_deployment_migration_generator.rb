# frozen_string_literal: true

require 'rails/generators'

module PostDeploymentMigration
  class PostDeploymentMigrationGenerator < Rails::Generators::NamedBase
    def create_migration_file
      timestamp = Time.now.utc.strftime('%Y%m%d%H%M%S')

      template "migration.rb", "db/post_migrate/#{timestamp}_#{file_name}.rb"
    end

    def migration_class_name
      file_name.camelize
    end
  end
end

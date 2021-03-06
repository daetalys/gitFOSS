# frozen_string_literal: true

module Packages
  module Npm
    class PackagePresenter
      include API::Helpers::RelatedResourcesHelpers

      attr_reader :name, :packages

      def initialize(name, packages)
        @name = name
        @packages = packages
      end

      def versions
        package_versions = {}

        packages.each_batch do |relation|
          relation.including_dependency_links
                  .preload_files
                  .each do |package|
                    package_file = package.package_files.last

                    next unless package_file

                    package_versions[package.version] = build_package_version(package, package_file)
                  end
        end

        package_versions
      end

      def dist_tags
        build_package_tags.tap { |t| t["latest"] ||= sorted_versions.last }
      end

      private

      def build_package_tags
        package_tags.to_h { |tag| [tag.name, tag.package.version] }
      end

      def build_package_version(package, package_file)
        {
          name: package.name,
          version: package.version,
          dist: {
            shasum: package_file.file_sha1,
            tarball: tarball_url(package, package_file)
          }
        }.tap do |package_version|
          package_version.merge!(build_package_dependencies(package))
        end
      end

      def tarball_url(package, package_file)
        expose_url "#{api_v4_projects_path(id: package.project_id)}" \
          "/packages/npm/#{package.name}" \
          "/-/#{package_file.file_name}"
      end

      def build_package_dependencies(package)
        dependencies = Hash.new { |h, key| h[key] = {} }

        package.dependency_links.each do |dependency_link|
          dependency = dependency_link.dependency
          dependencies[dependency_link.dependency_type][dependency.name] = dependency.version_pattern
        end

        dependencies
      end

      def sorted_versions
        versions = packages.pluck_versions.compact
        VersionSorter.sort(versions)
      end

      def package_tags
        Packages::Tag.for_packages(packages)
                     .preload_package
      end
    end
  end
end

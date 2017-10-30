# frozen_string_literal: true

require "dependabot/metadata_finders/ruby/bundler"
require "dependabot/metadata_finders/python/pip"
require "dependabot/metadata_finders/java_script/npm"
require "dependabot/metadata_finders/java_script/yarn"
require "dependabot/metadata_finders/java/maven"
require "dependabot/metadata_finders/php/composer"
require "dependabot/metadata_finders/git/submodules"
require "dependabot/metadata_finders/docker/docker"

module Dependabot
  module MetadataFinders
    # rubocop:disable Metrics/CyclomaticComplexity
    def self.for_package_manager(package_manager)
      case package_manager
      when "bundler" then MetadataFinders::Ruby::Bundler
      when "npm" then MetadataFinders::JavaScript::Npm
      when "yarn" then MetadataFinders::JavaScript::Yarn
      when "maven" then MetadataFinders::Java::Maven
      when "pip" then MetadataFinders::Python::Pip
      when "composer" then MetadataFinders::Php::Composer
      when "submodules" then MetadataFinders::Git::Submodules
      when "docker" then MetadataFinders::Docker::Docker
      else raise "Unsupported package_manager #{package_manager}"
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity
  end
end

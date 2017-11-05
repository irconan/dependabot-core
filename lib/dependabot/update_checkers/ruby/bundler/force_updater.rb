# frozen_string_literal: true

require "bundler_definition_version_patch"
require "bundler_git_source_patch"

require "dependabot/update_checkers/ruby/bundler"
require "dependabot/shared_helpers"
require "dependabot/errors"

module Dependabot
  module UpdateCheckers
    module Ruby
      class Bundler
        class ForceUpdater
          def initialize(dependency:, dependency_files:, credentials:,
                         target_version:)
            @dependency       = dependency
            @dependency_files = dependency_files
            @credentials      = credentials
            @target_version   = target_version
          end

          def force_update
            in_a_temporary_bundler_context do
              unlocked_gems = [dependency.name]

              begin
                definition = build_definition(unlocked_gems: unlocked_gems)
                definition.resolve_remotely!
                dep = definition.resolve.find { |d| d.name == dependency.name }
                { version: dep.version, unlocked_gems: unlocked_gems }
              rescue ::Bundler::VersionConflict => error
                # TODO: Not sure this won't unlock way too many things...
                to_unlock = error.cause.conflicts.values.flat_map do |conflict|
                  conflict.requirement_trees.map { |r| r.first.name }
                end
                raise unless (to_unlock - unlocked_gems).any?
                unlocked_gems |= to_unlock
                retry
              end
            end
          rescue SharedHelpers::ChildProcessFailed => error
            msg = error.error_class + " with message: " + error.error_message
            raise Dependabot::DependencyFileNotResolvable, msg
          end

          private

          attr_reader :dependency, :dependency_files, :credentials,
                      :target_version

          #########################
          # Bundler context setup #
          #########################

          def in_a_temporary_bundler_context
            SharedHelpers.in_a_temporary_directory do
              write_temporary_dependency_files

              SharedHelpers.in_a_forked_process do
                # Remove installed gems from the default Rubygems index
                ::Gem::Specification.all = []

                # Set auth details
                credentials.each do |cred|
                  ::Bundler.settings.set_command_option(
                    cred["host"],
                    cred["token"] || "#{cred['username']}:#{cred['password']}"
                  )
                end

                yield
              end
            end
          end

          def build_definition(unlocked_gems:)
            definition = ::Bundler::Definition.build(
              "Gemfile",
              lockfile&.name,
              gems: unlocked_gems
            )

            # Remove the Gemfile / gemspec requirements on the gems we're
            # unlocking (i.e., completely unlock them)
            unlocked_gems.each do |gem_name|
              unlock_gem(definition: definition, gem_name: gem_name)
            end

            # Set the requirement for the gem we're forcing an update of
            new_req = Gem::Requirement.create("= #{target_version}")
            definition.dependencies.
              find { |d| d.name == dependency.name }.
              instance_variable_set(:@requirement, new_req)

            definition
          end

          def unlock_gem(definition:, gem_name:)
            dep = definition.dependencies.find { |d| d.name == gem_name }
            version = definition.locked_gems.specs.
                      find { |d| d.name == gem_name }.version

            dep&.instance_variable_set(
              :@requirement,
              Gem::Requirement.create(">= #{version}")
            )
          end

          def gemfile
            dependency_files.find { |f| f.name == "Gemfile" }
          end

          def lockfile
            dependency_files.find { |f| f.name == "Gemfile.lock" }
          end

          def write_temporary_dependency_files
            dependency_files.each do |file|
              path = file.name
              FileUtils.mkdir_p(Pathname.new(path).dirname)
              File.write(path, file.content)
            end
          end
        end
      end
    end
  end
end

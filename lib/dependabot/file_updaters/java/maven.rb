# frozen_string_literal: true

require "nokogiri"
require "dependabot/file_updaters/base"

module Dependabot
  module FileUpdaters
    module Java
      class Maven < Dependabot::FileUpdaters::Base
        DEPENDENCY_SELECTOR = "dependencies > dependency, plugins plugin"

        def self.updated_files_regex
          [/^pom\.xml$/]
        end

        def updated_dependency_files
          [updated_file(file: pom, content: updated_pom_content)]
        end

        private

        def check_required_files
          %w(pom.xml).each do |filename|
            raise "No #{filename}!" unless get_original_file(filename)
          end
        end

        def updated_pom_content
          doc = Nokogiri::XML(pom.content)
          original_node = doc.css(DEPENDENCY_SELECTOR).find do |node|
            node_name = [
              node.at_css("groupId").content,
              node.at_css("artifactId").content
            ].join(":")
            node_name == dependency.name
          end

          version_content = original_node.at_css("version").content

          if version_content.start_with?("${")
            property_name = version_content.strip[2..-2]

            doc.remove_namespaces!
            doc.at_xpath("//properties/#{property_name}").content =
              dependency.version
          else
            original_node.at_css("version").content = dependency.version
          end

          doc.to_xml
        end

        def pom
          @pom ||= get_original_file("pom.xml")
        end
      end
    end
  end
end

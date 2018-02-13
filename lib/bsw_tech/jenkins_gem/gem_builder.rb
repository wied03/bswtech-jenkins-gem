module BswTech
  module JenkinsGem
    class GemBuilder
      PREFIX = 'jenkins-plugin-proxy'
      DEPENDENCY_REMAPS = {
        # For some reason, Jenkins seems to reference invalid dependency versions sometimes
        'matrix-project' => {
          '1.7.1' => '1.12'
        }
      }
      JENKINS_CORE_PACKAGE = 'jenkins-core'
      METADATA_JENKINS_NAME = 'jenkins_name'
      METADATA_JENKINS_VERSION = 'jenkins_version'
      METADATA_SHA1 = 'sha1'
      SEPARATOR = ': '

      attr_reader :gem_listing

      def self.from_update_json(file_blob, jenkins_versions)
        fail 'File blob contents is required' unless file_blob && !file_blob.empty?
        metadata = get_hash file_blob
        gem_listing = metadata['plugins'].map do |plugin_name, info|
          begin
            Gem::Specification.new do |s|
              s.name = get_name(plugin_name)
              excerpt = info['excerpt'].gsub('TODO:', '')
              s.summary = excerpt
              jenkins_version = info['version']
              s.version = format_version(jenkins_version)
              s.metadata = {
                METADATA_JENKINS_VERSION => jenkins_version,
                METADATA_JENKINS_NAME => plugin_name,
                METADATA_SHA1 => info['sha1']
              }
              s.homepage = info['wiki']
              developers = info['developers'].map do |dev|
                dev['email'] || dev['developerId']
              end
              s.authors = developers.any? ? developers : ['unknown']
              info['dependencies'].each do |dependency|
                add_dependency dependency, s
              end
              add_core_jenkins(info['requiredCore'], s)
            end
          rescue StandardError => e
            puts "Error while parsing plugin '#{plugin_name}' info #{info}"
            raise e
          end
        end
        jenkins_versions.each do |jenkins_version|
          gem_listing << Gem::Specification.new do |s|
            s.name = get_name(JENKINS_CORE_PACKAGE)
            s.summary = 'Jenkins stub'
            s.version = format_version(jenkins_version)
            s.homepage = 'https://www.jenkins.io'
            s.authors = ['alotofpeople']
          end
        end
        new(gem_listing)
      end

      def self.from_hpi(manifest_contents)
        properties = get_prop_hash manifest_contents
        gem_spec = Gem::Specification.new do |s|
          plugin_name = properties['Extension-Name']
          s.name = get_name(plugin_name)
          s.description = properties['Specification-Title']
          s.summary = properties['Long-Name']
          jenkins_version = properties['Plugin-Version']
          s.version = format_version(jenkins_version)
          s.metadata = {
            METADATA_JENKINS_VERSION => jenkins_version,
            METADATA_JENKINS_NAME => plugin_name
          }
          s.homepage = properties['Url']
          developers = properties['Plugin-Developers'].split(',')
          s.authors = developers.any? ? developers : ['unknown']
          # Handle no dependency cases
          dependencies = properties['Plugin-Dependencies'] || ''
          dependencies.split(',').each do |dependency_string|
            name_version, props = dependency_string.split ';'
            props = props ? Hash[props.split(',').map {|kv| kv.split(':=')}] : {}
            name, version = name_version.split(':')
            dependency = {
              'optional' => props['resolution'],
              'version' => version,
              'name' => name
            }
            add_dependency dependency, s
          end
          add_core_jenkins properties['Jenkins-Version'],
                           s
        end
        new([gem_spec])
      end

      def initialize(gem_listing)
        @gem_listing = gem_listing
      end

      private_class_method :new

      private

      class << self
        def get_prop_hash(manifest_contents)
          consistent_lines = manifest_contents.split("\n").inject([]) do |line_array, current_line|
            previous_line = line_array.pop
            # Manifest lines are wrapped at a fixed boundary
            new_lines = if current_line.start_with? ' '
                          # Trim off the extra space
                          [previous_line + current_line[1..-1]]
                        else
                          [previous_line, current_line]
                        end
            line_array + new_lines.compact
          end

          Hash[consistent_lines.map do |property_line|
            parts = property_line.split SEPARATOR
            [parts[0], parts[1..-1].join(SEPARATOR)]
          end]
        end

        def add_core_jenkins(version,
                             gem_spec)
          gem_spec.add_runtime_dependency get_name(JENKINS_CORE_PACKAGE),
                                          get_dependency_version(version)
        end

        def get_dependency_version(version)
          ">= #{version}"
        end

        def get_name(package)
          "#{PREFIX}-#{package}"
        end

        def add_dependency(dependency, gem_spec)
          return if dependency['optional']
          candidate_version = dependency['version']
          dependency_name = dependency['name']
          remap = DEPENDENCY_REMAPS[dependency_name]
          if remap
            new_version = remap[candidate_version]
            candidate_version = new_version if new_version
          end
          candidate_version = format_version candidate_version
          gem_spec.add_runtime_dependency get_name(dependency_name),
                                          get_dependency_version(candidate_version)
        end

        def format_version(jenkins_number)
          # + is not a legal character in GEM versions but we can change it back later
          jenkins_number.gsub('+', '.')
            .gsub('-', '.') # Rubygems treats dash as a pre-release version
        end

        def get_hash(file_blob)
          trailing_end_index = file_blob.rindex(');')
          only_json = file_blob[0..trailing_end_index - 1].gsub('updateCenter.post(', '')
          JSON.parse only_json
        end
      end
    end
  end
end

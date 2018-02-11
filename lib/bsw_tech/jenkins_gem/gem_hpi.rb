require 'bsw_tech/jenkins_gem/gem_util'

module BswTech
  module JenkinsGem
    class GemHpi
      include GemUtil

      def initialize(gem)
        @gem = gem
      end

      def merge_hpi(index_gem_path)
        spec = @gem.spec
        metadata = spec.metadata
        jenkins_name = metadata[BswTech::JenkinsGem::UpdateJsonParser::METADATA_JENKINS_NAME]
        jenkins_version = metadata[BswTech::JenkinsGem::UpdateJsonParser::METADATA_JENKINS_VERSION]
        url = "https://updates.jenkins.io/download/plugins/#{jenkins_name}/#{jenkins_version}/#{jenkins_name}.hpi"
        hpi_response = begin
          fetch(url)
        rescue StandardError => e
          puts "Problem fetching HPI from #{url} - #{e}"
          raise e
        end
        return [404, hpi_response.body] unless hpi_response.is_a? Net::HTTPSuccess
        temp_file = Tempfile.new('.zip')
        begin
          temp_file.write hpi_response.body
          temp_file.rewind
          signature = Digest::SHA1.file temp_file
          temp_file.rewind
          expected_sha = metadata[BswTech::JenkinsGem::UpdateJsonParser::METADATA_SHA1]
          actual = signature.base64digest
          fail "ZIP failed SHA1 check. Expected '#{expected_sha}', got '#{actual}'" unless actual == expected_sha
          begin
            Dir.mktmpdir 'gem_temp_dir' do |local_temp_path|
              @gem.extract_files local_temp_path
              Zip::File.open(temp_file) do |zip_file|
                zip_file.each do |entry|
                  full_path = File.join(local_temp_path, entry.name)
                  entry.extract(full_path)
                end
              end
              Dir.chdir(local_temp_path) do
                spec.files = Dir['**/*']
                built_gem_path = with_quiet_gem do
                  ::Gem::Package.build spec
                end
                puts "Copying #{built_gem_path} to #{index_gem_path}"
                FileUtils.copy built_gem_path, index_gem_path
              end
            end
          rescue StandardError => e
            puts "zip/GEM error #{e}"
            raise e
          end
        ensure
          temp_file.close
          temp_file.unlink
        end
      end
    end
  end
end

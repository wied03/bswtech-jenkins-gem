require 'bsw_tech/jenkins_gem/gem_util'

module BswTech
  module JenkinsGem
    class GemHpi
      include GemUtil

      def initialize(gem_path,
                     certificate_path,
                     private_key_path)
        @gem_path = gem_path
        @gem = Gem::Package.new gem_path
        @private_key_path = private_key_path
        @certificate_path = certificate_path
      end

      def merge_hpi
        with_downloaded_hpi do |temp_file|
          with_gem_to_modify do |local_temp_path, spec|
            Zip::File.open(temp_file) do |zip_file|
              zip_file.each do |entry|
                full_path = File.join(local_temp_path, entry.name)
                entry.extract(full_path)
                spec.files = Dir['**/*']
              end
            end
          end
        end
      end

      def sign_gem
        with_gem_to_modify do |_, spec|
          spec.cert_chain = [@certificate_path]
          spec.signing_key = @private_key_path
        end
      end

      private

      def with_gem_to_modify
        Dir.mktmpdir 'gem_temp_dir' do |local_temp_path|
          @gem.extract_files local_temp_path
          Dir.chdir(local_temp_path) do
            spec = @gem.spec
            yield local_temp_path, spec
            built_gem_path = with_quiet_gem do
              ::Gem::Package.build spec
            end
            FileUtils.copy built_gem_path, @gem_path
          end
        end
      end

      def with_downloaded_hpi
        metadata = @gem.spec.metadata
        jenkins_name = metadata[BswTech::JenkinsGem::GemBuilder::METADATA_JENKINS_NAME]
        jenkins_version = metadata[BswTech::JenkinsGem::GemBuilder::METADATA_JENKINS_VERSION]
        url = "https://updates.jenkins.io/download/plugins/#{jenkins_name}/#{jenkins_version}/#{jenkins_name}.hpi"
        hpi_response = begin
          fetch(url)
        rescue StandardError => e
          puts "Problem fetching HPI from #{url} - #{e}"
          raise e
        end
        return [404, hpi_response.body] unless hpi_response.is_a? Net::HTTPSuccess
        temp_file = Tempfile.new('.zip')
        temp_file.write hpi_response.body
        temp_file.rewind
        signature = Digest::SHA1.file temp_file
        temp_file.rewind
        expected_sha = metadata[BswTech::JenkinsGem::GemBuilder::METADATA_SHA1]
        actual = signature.base64digest
        fail "ZIP failed SHA1 check. Expected '#{expected_sha}', got '#{actual}'" unless actual == expected_sha
        yield temp_file
      ensure
        temp_file.close
        temp_file.unlink
      end
    end
  end
end

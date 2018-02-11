require 'spec_helper'
require 'bsw_tech/jenkins_gem/gem_hpi'

fdescribe BswTech::JenkinsGem::GemHpi do
  include BswTech::JenkinsGem::GemUtil

  describe '#merge_hpi' do
    subject(:final_gem) do
      gem_hpi = BswTech::JenkinsGem::GemHpi.new(gem)
      output_path = File.join(@local_temp_path, 'output')
      FileUtils.mkdir_p output_path
      gem_hpi.merge_hpi(output_path)
      file = File.join(output_path, 'some_plugin-1.2.3.gem')
      fail 'Non existent GEM' unless File.exist? file
      package = with_quiet_gem do
        Gem::Package.new file
      end
      package.spec
    end

    let(:gem) do
      spec = Gem::Specification.new do |s|
        s.name = 'some_plugin'
        s.summary = 'the details'
        s.version = '1.2.3'
        s.metadata = {
          BswTech::JenkinsGem::UpdateJsonParser::METADATA_JENKINS_VERSION => '4.5.3-2.1',
          BswTech::JenkinsGem::UpdateJsonParser::METADATA_JENKINS_NAME => 'apache-httpcomponents-client-4-api',
          BswTech::JenkinsGem::UpdateJsonParser::METADATA_SHA1 => actual_sha
        }
        s.homepage = 'http://homepage'
        s.authors = ['unknown']
      end
      input_path = File.join(@local_temp_path, 'input')
      FileUtils.mkdir_p input_path
      Dir.chdir(input_path) do
        with_quiet_gem do
          Gem::Package.build spec
        end
        Gem::Package.new File.join(input_path, 'some_plugin-1.2.3.gem')
      end
    end

    around do |example|
      Dir.mktmpdir 'gem_temp_dir' do |local_temp_path|
        @local_temp_path = local_temp_path
        example.run
      end
    end

    context 'valid' do
      let(:actual_sha) {'G3rmp5e32wmL2mFnTI3QN+WCDtE='}

      describe '#files' do
        subject {final_gem.files}

        its(:length) {is_expected.to eq 10}
      end
    end

    context 'invalid SHA' do
      let(:actual_sha) {'foobar'}

      it 'fails' do
        expect {final_gem}.to raise_error /ZIP failed SHA1 check/
      end
    end
    pending 'write this'
  end
end

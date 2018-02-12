require 'spec_helper'
require 'bsw_tech/jenkins_gem/gem_hpi'

fdescribe BswTech::JenkinsGem::GemHpi do
  include BswTech::JenkinsGem::GemUtil

  let(:spec_dir) {File.join(Dir.pwd, 'spec')}
  let(:gem_hpi) do
    BswTech::JenkinsGem::GemHpi.new(gem_path,
                                    File.join(spec_dir, 'repo_util_cert.pem'),
                                    File.join(spec_dir, 'repo_util_key.pem'))
  end

  let(:gem_path) {File.join(@local_temp_path, 'some_plugin-1.2.3.gem')}

  before do
    puts 'Building test gem spec'
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
    Dir.chdir(@local_temp_path) do
      with_quiet_gem do
        Gem::Package.build spec
      end
      puts 'Test gem spec built'
    end
  end

  let(:actual_sha) {'G3rmp5e32wmL2mFnTI3QN+WCDtE='}

  subject(:final_gem) do
    puts 'Parsing finished GEM product'
    file = File.join(@local_temp_path, 'some_plugin-1.2.3.gem')
    fail 'Non existent GEM' unless File.exist? file
    package = with_quiet_gem do
      Gem::Package.new file
    end
    package.spec
  end

  around do |example|
    Dir.mktmpdir 'gem_temp_dir' do |local_temp_path|
      @local_temp_path = local_temp_path
      example.run
    end
  end

  describe '#merge_hpi' do
    before {do_merge}

    def do_merge
      puts 'Calling merge_hpi'
      gem_hpi.merge_hpi
    end

    context 'valid' do
      describe '#files' do
        subject {final_gem.files}

        its(:length) {is_expected.to eq 10}
      end
    end

    context 'invalid SHA' do
      let(:actual_sha) {'foobar'}

      def do_merge
        # Need to test error
      end

      it 'fails' do
        expect {gem_hpi.merge_hpi}.to raise_error /ZIP failed SHA1 check/
      end
    end
  end

  describe '#sign_gem' do
    before {gem_hpi.sign_gem}

    it 'signature' do
      expect(final_gem.cert_chain.length).to eq 1
    end
  end
end

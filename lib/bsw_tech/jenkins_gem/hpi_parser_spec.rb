require 'spec_helper'
require 'bsw_tech/jenkins_gem/hpi_parser'
require 'bsw_tech/jenkins_gem/gem_util'
require 'tempfile'

describe BswTech::JenkinsGem::HpiParser do
  include BswTech::JenkinsGem::GemUtil

  subject(:parser) {BswTech::JenkinsGem::HpiParser.new zip_stream}

  describe '#gem_spec' do
    subject(:spec) {parser.gem_spec}

    let(:zip_stream) do
      body = fetch('https://updates.jenkins.io/download/plugins/git/3.7.0/git.hpi').body
      @temp_file.write body
      @temp_file.path
    end

    around do |example|
      @temp_file = Tempfile.new('.zip')
      begin
        example.run
      ensure
        @temp_file.close
        @temp_file.unlink
      end
    end

    it 'parses correctly' do
      expect(spec.name).to eq 'jenkins-plugin-proxy-git'
      expect(spec.version).to eq Gem::Version.new('3.7.0')
    end
  end
end

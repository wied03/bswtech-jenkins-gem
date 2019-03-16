require 'spec_helper'
require 'rack/test'
index_directory = File.join(File.dirname(__FILE__), 'test_gem_index')
ENV['INDEX_DIRECTORY'] = index_directory
spec_dir = File.join(File.dirname(__FILE__), '..', '..', '..', 'spec')
ENV['GEM_CERTIFICATE_PATH'] = File.join(spec_dir, 'repo_util_cert.pem')
ENV['GEM_PRIVATE_KEY_PATH'] = File.join(spec_dir, 'repo_util_key.pem')
require 'bsw_tech/jenkins_gem/gem_server'

describe 'GEM Server' do
  include Rack::Test::Methods

  before(:context) {FileUtils.rm_rf index_directory}
  after(:context) {FileUtils.rm_rf index_directory}

  let(:fury_mock) {instance_double(Gemfury::Client)}
  let(:existing_versions) do
    Hash.new do |hash, key|
      hash[key] = []
    end
  end

  def app
    BswTech::JenkinsGem::GemServer
  end

  describe 'specs' do
    subject do
      response = get '/specs.4.8.gz'
      Marshal.load(Gem.gunzip(response.body))
    end

    its(:length) {is_expected.to be > 1500}
  end

  describe 'individual GEM metadata' do
    subject {get '/quick/Marshal.4.8/jenkins-plugin-proxy-git-3.9.3.gemspec.rz'}

    its(:ok?) {is_expected.to eq true}
  end

  describe 'individual GEMs' do
    before {get '/specs.4.8.gz'}

    subject(:gem) do
      unless response.ok?
        fail "Request failed! #{response.body}"
      end
      package = ::Gem::Package.new StringIO.new(response.body)
      package.spec
    end

    describe 'Jenkins core and Git' do
      before {
        get '/gems/jenkins-plugin-proxy-git-3.9.3.gem'
      }
      let(:response) {get '/gems/jenkins-plugin-proxy-jenkins-core-2.164.1.gem'}

      describe 'GEM' do
        its(:name) {is_expected.to eq 'jenkins-plugin-proxy-jenkins-core'}
        its(:files) {is_expected.to eq []}
        its(:cert_chain) {is_expected.to_not eq []}
      end

      it 'uploads to Gemfury' do
        # trigger the fetch
        puts gem
        lines = File.readlines File.join(index_directory, 'fury_files.txt')
        expect(lines.length).to eq 2
        expect(lines[0].strip).to end_with 'jenkins-plugin-proxy-git-3.9.3.gem'
        expect(lines[1].strip).to end_with 'jenkins-plugin-proxy-jenkins-core-2.164.1.gem'
      end
    end

    context 'not found' do
      subject(:response) {get '/gems/foobar.gem'}

      its(:ok?) {is_expected.to eq false}
      its(:status) {is_expected.to eq 404}
    end
  end
end

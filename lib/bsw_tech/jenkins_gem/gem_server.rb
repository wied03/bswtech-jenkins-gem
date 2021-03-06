require 'sinatra/base'
require 'net/http'
require 'rubygems/package'
require 'rubygems/indexer'
require 'fileutils'
require 'bsw_tech/jenkins_gem/gem_builder'
require 'bsw_tech/jenkins_gem/gem_util'
require 'bsw_tech/jenkins_gem/jenkins_list_fetcher'
require 'bsw_tech/jenkins_gem/gem_hpi'
require 'zip'
require 'tmpdir'
require 'tempfile'

module BswTech
  module JenkinsGem
    class GemServer < Sinatra::Application
      set :port, 9292
      include BswTech::JenkinsGem::GemUtil

      def initialize
        super
        @index_dir = ENV['INDEX_DIRECTORY']
        raise 'Set the INDEX_DIRECTORY ENV variable' unless @index_dir
        # Indexer looks here
        @gems_dir = File.join(@index_dir, 'gems')
        @queue_file = File.join(@index_dir, 'fury_files.txt')
        FileUtils.rm_rf @queue_file if File.exist?(@queue_file)
        @cert_path = ENV['GEM_CERTIFICATE_PATH']
        fail 'Set the GEM_CERTIFICATE_PATH ENV variable' unless @cert_path && File.exists?(@cert_path)
        @private_key_path = ENV['GEM_PRIVATE_KEY_PATH']
        fail 'Set the GEM_PRIVATE_KEY_PATH ENV variable' unless @private_key_path && File.exists?(@private_key_path)
      end

      def add_to_fury_queue(gem_path)
        unless File.exist?(@queue_file)
          puts 'Initializing Fury upload queue file...'
          FileUtils.touch @queue_file
        end
        # avoid flush issues
        File.open(@queue_file, 'a') do |file|
          file.puts gem_path
        end
      end

      get '/quick/Marshal.4.8/:rz_file' do |rz_file|
        File.open(File.join(@index_dir, 'quick', 'Marshal.4.8', rz_file), 'rb')
      end

      get '/specs.4.8.gz' do
        build_index
        File.open(File.join(@index_dir, 'specs.4.8.gz'), 'rb')
      end

      get '/gems/:gem_filename' do |gem_filename|
        path = File.absolute_path(File.join(@gems_dir, gem_filename))
        next [404, "Unable to find gem #{gem_filename}"] unless File.exists? path
        gem = ::Gem::Package.new path
        spec = gem.spec
        hpi_util = BswTech::JenkinsGem::GemHpi.new(path, @cert_path, @private_key_path)
        new_gem = false
        unless spec.name.include?(BswTech::JenkinsGem::GemBuilder::JENKINS_CORE_PACKAGE)
          # Files might already be there
          unless spec.files.any?
            hpi_util.merge_hpi
            new_gem = true
          end
        end
        unless spec.cert_chain.any?
          puts "Signing gem #{path}"
          hpi_util.sign_gem
          new_gem = true
        end
        if new_gem
          puts "Adding #{path} to Fury queue file"
          add_to_fury_queue path
        end
        File.open(path, 'rb')
      end

      # TODO: Somewhere, use the Jenkins metadata JSON to verify if any security problems exist

      def build_index
        if File.exist?(@index_dir)
          puts 'Index already exists, returning existing index'
          return
        end
        puts "Fetching Jenkins plugin list..."

        jenkins_versions = BswTech::JenkinsGem::JenkinsListFetcher.get_available_versions

        parser = begin
          update_response = fetch('https://updates.jenkins-ci.org/update-center.json').body
          BswTech::JenkinsGem::GemBuilder.from_update_json(update_response, jenkins_versions)
        rescue StandardError => e
          puts "Problem fetching Jenkins info #{e}"
          raise e
        end

        gem_list = parser.gem_listing
        # TODO: See comment below re: updated if already there
        FileUtils.rm_rf @index_dir
        FileUtils.mkdir_p @index_dir
        FileUtils.mkdir_p @gems_dir
        puts "Fetched #{gem_list.length} GEM specs from Jenkins, Writing GEM skeletons to #{@gems_dir}"
        Dir.chdir(@gems_dir) do
          with_quiet_gem do
            gem_list.each do |gemspec|
              begin
                ::Gem::Package.build gemspec
              rescue StandardError => e
                puts "Error while writing GEM for #{gemspec.name}, #{e}"
                raise e
              end
            end
          end
        end
        # https://blog.packagecloud.io/eng/2015/12/15/rubygem-index-internals/
        # TODO: Can this be updated if already there?
        Gem::Indexer.new(@index_dir,
                         { build_modern: true }).generate_index
      end
    end
  end
end

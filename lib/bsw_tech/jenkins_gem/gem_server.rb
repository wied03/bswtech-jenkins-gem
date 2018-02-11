require 'sinatra'
require 'net/http'
require 'rubygems/package'
require 'rubygems/indexer'
require 'fileutils'
require 'bsw_tech/jenkins_gem/update_json_parser'
require 'bsw_tech/jenkins_gem/jenkins_list_fetcher'
require 'zip'
require 'tmpdir'
require 'digest'
require 'tempfile'

index_dir = ENV['INDEX_DIRECTORY']
raise 'Set the INDEX_DIRECTORY variable' unless index_dir
# Indexer looks here
gems_dir = File.join(index_dir, 'gems')

get '/quick/Marshal.4.8/:rz_file' do |rz_file|
  File.open(File.join(index_dir, 'quick', 'Marshal.4.8', rz_file), 'rb')
end

get '/specs.4.8.gz' do
  build_index(index_dir, gems_dir)
  File.open(File.join(index_dir, 'specs.4.8.gz'), 'rb')
end

get '/gems/:gem_filename' do |gem_filename|
  path = File.absolute_path(File.join(gems_dir, gem_filename))
  next [404, "Unable to find gem #{gem_filename}"] unless File.exists? path
  gem = ::Gem::Package.new path
  spec = gem.spec
  unless spec.name.include?(BswTech::JenkinsGem::UpdateJsonParser::JENKINS_CORE_PACKAGE)
    add_hpi_to_gem gem, path unless spec.files.any?
  end
  File.open(path, 'rb')
end

# TODO: Somewhere, use the Jenkins metadata JSON to verify if any security problems exist
def add_hpi_to_gem(gem, index_gem_path)

end

# TODO: ETag based index expire?
def build_index(index_dir, gems_dir)
  if File.exist?(index_dir)
    return
  end
  puts "Fetching Jenkins plugin list..."

  jenkins_versions = BswTech::JenkinsGem::JenkinsListFetcher.get_available_versions

  parser = begin
    update_response = fetch('https://updates.jenkins-ci.org/update-center.json').body
    BswTech::JenkinsGem::UpdateJsonParser.new(update_response, jenkins_versions)
  rescue StandardError => e
    puts "Problem fetching Jenkins info #{e}"
    raise e
  end

  gem_list = parser.gem_listing
  # TODO: See comment below re: updated if already there
  FileUtils.rm_rf index_dir
  FileUtils.mkdir_p index_dir
  FileUtils.mkdir_p gems_dir
  puts "Fetched #{gem_list.length} GEM specs from Jenkins, Writing GEM skeletons to #{gems_dir}"
  Dir.chdir(gems_dir) do
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
  Gem::Indexer.new(index_dir,
                   { build_modern: true }).generate_index
end

require 'rspec/core/rake_task'

Bundler::GemHelper.install_tasks

if ENV['GENERATE_REPORTS'] == 'true'
  require 'ci/reporter/rake/rspec'
  task :spec => 'ci:setup:rspec'
end

desc 'Run unit tests'
RSpec::Core::RakeTask.new(:spec) do |task|
  task.pattern = 'lib/**/*_spec.rb'
end

desc 'Cleans up'
task :clean do
  rm_rf 'pkg'
end

def gem_spec
  Bundler.definition.specs['bswtech-jenkins-gem'][0]
end

task :dump_version do
  puts gem_spec.version
end

desc 'Installs and verifies that GEM is signed'
task :verify_sign => :build do
  our_gem_spec = gem_spec
  gem_file = FileList['pkg/*.gem'][0]
  puts 'Testing out a GEM install with high security'
  sh "gem install -P HighSecurity #{gem_file}"
  puts 'GEM was successfully installed, now removing'
  sh "gem uninstall #{our_gem_spec.name} -v #{our_gem_spec.version} -x"
end

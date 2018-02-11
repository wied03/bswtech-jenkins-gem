require 'rspec/core/rake_task'

Bundler::GemHelper.install_tasks

if ENV['GENERATE_REPORTS'] == 'true'
  require 'ci/reporter/rake/rspec'
  task :spec => 'ci:setup:rspec'
end

desc 'Run unit tests'
RSpec::Core::RakeTask.new(:spec) do |task|
  task.pattern = 'lib/**/*_spec.rb'
  task.rspec_opts = '-I spec'
end

desc 'Cleans up'
task :clean do
  rm_rf 'pkg'
end

$LOAD_PATH << './lib'
require 'rake'

src='lib'

Gem::Specification.new do |s|
  s.name = 'bswtech-jenkins-gem'
  s.files = FileList["#{src}/**/*.rb",
                     "#{src}/**/*.rake"].exclude('**/*_spec.rb')
  # Work around prerelease nil question
  s.version = String.new(ENV['version_number'] || '1.0.0')
  s.summary = 'Jenkins GEM utility'
  s.description = s.summary
  s.rdoc_options << '--inline-source' << '--line-numbers'
  s.author = 'Brady Wied'
  s.email = 'brady@bswtechconsulting.com'
  s.add_runtime_dependency 'rubyzip', '~> 1.2'
  s.add_runtime_dependency 'sinatra', '~> 2.0'
  s.add_runtime_dependency 'gemfury', '~> 0.7'
  s.executables << 'jenkins_bundle_install'
end

require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "rbbt-sent-www"
    gem.summary = %Q{SENT online interface}
    gem.description = %Q{This package contains a SOAP web server and a merb application.}
    gem.email = "miguel.vazquez@fdi.ucm.es"
    gem.homepage = "http://github.com/mikisvaz/rbbt-sent-www"
    gem.authors = ["Miguel Vazquez"]

    gem.files = Dir['merb', 'webservice', 'lib/*']
    gem.files.exclude 'merb/tmp/*' 
    gem.files.exclude 'merb/public/tmp'
    gem.files.exclude 'merb/public/results'
    gem.files.exclude 'merb/public/data'

    gem.add_dependency('rbbt')
    gem.add_dependency('rbbt-genecodis')

    gem.add_dependency('merb')
    gem.add_dependency('simplews', '>= 1.8')
    gem.add_dependency('rmail')
    gem.add_dependency('RedCloth')
    gem.add_dependency('rand')
    gem.add_dependency('xml-simple')
    gem.add_dependency('markaby')


    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "rbbt-sent-www #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

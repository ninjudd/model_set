require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name = "model_set"
    s.summary = %Q{Easy manipulation of sets of ActiveRecord models}
    s.email = "code@justinbalthrop.com"
    s.homepage = "http://github.com/ninjudd/model_set"
    s.description = "Easy manipulation of sets of ActiveRecord models"
    s.authors = ["Justin Balthrop"]
    s.add_dependency('ordered_set',   '>= 1.0.1')
    s.add_dependency('deep_clonable', '>= 1.1.0')
    s.add_dependency('activerecord', '>= 2.0.0')
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

Rake::TestTask.new do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = false
end

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'model_set'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |t|
    t.libs << 'test'
    t.test_files = FileList['test/**/*_test.rb']
    t.verbose = true
  end
rescue LoadError
end

task :default => :test

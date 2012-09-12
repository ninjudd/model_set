# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'model_set/version'

Gem::Specification.new do |gem|
  gem.name          = "test"
  gem.version       = ModelSet::VERSION
  gem.authors       = ["Justin Balthrop"]
  gem.email         = ["git@justinbalthrop.com"]
  gem.description   = %q{Easy manipulation of sets of ActiveRecord models}
  gem.summary       = gem.description
  gem.homepage      = "https://github.com/ninjudd/model_set"

  gem.add_development_dependency 'shoulda'
  gem.add_development_dependency 'mocha'
  gem.add_development_dependency 'rsolr'
  gem.add_development_dependency 'json'
  gem.add_development_dependency 'activerecord-postgresql-adapter'

  gem.add_dependency 'ordered_set',   '>= 1.0.1'
  gem.add_dependency 'deep_clonable', '>= 1.1.0'
  gem.add_dependency 'activerecord',  '~> 2.3.9'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end

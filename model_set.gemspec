Gem::Specification.new do |s|
  s.name = %q{model_set}
  s.version = "0.9.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Justin Balthrop"]
  s.date = %q{2009-04-17}
  s.description = %q{Easy manipulation of sets of ActiveRecord models}
  s.email = %q{code@justinbalthrop.com}
  s.files = ["README.rdoc", "VERSION.yml", "lib/model_set", "lib/model_set/conditioned.rb", "lib/model_set/conditions.rb", "lib/model_set/query.rb", "lib/model_set/raw_query.rb", "lib/model_set/raw_sql_query.rb", "lib/model_set/set_query.rb", "lib/model_set/solr_query.rb", "lib/model_set/sphinx_query.rb", "lib/model_set/sql_base_query.rb", "lib/model_set/sql_query.rb", "lib/model_set.rb", "lib/multi_set.rb", "test/model_set_test.rb", "test/multi_set_test.rb", "test/test_helper.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/ninjudd/model_set}
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.2.0}
  s.summary = %q{Easy manipulation of sets of ActiveRecord models}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if current_version >= 3 then
    else
    end
  else
  end
end

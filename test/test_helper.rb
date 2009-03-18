require 'test/unit'

$:.unshift(File.dirname(__FILE__) + '/../../deep_clonable/lib')

require File.dirname(__FILE__) + '/../lib/model_set'

require 'pp'

ActiveRecord::Base.establish_connection(
  :adapter  => "postgresql",
  :host     => "localhost",
  :username => "postgres",
  :password => "",
  :database => "model_set_test"
)

class << Test::Unit::TestCase
  def test(name, &block)
    test_name = "test_#{name.gsub(/[\s\W]/,'_')}"
    raise ArgumentError, "#{test_name} is already defined" if self.instance_methods.include? test_name
    define_method test_name, &block
  end
end

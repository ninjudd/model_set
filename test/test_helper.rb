require 'test/unit'
require File.dirname(__FILE__) + '/../lib/model_set'

require 'pp'
require 'model_factory'

class Robot
  attr_writer :id
  attr_accessor :name, :classification

  def initialize(opts = {})
    @id             = opts[:id]
    @name           = opts[:name]
    @classification = opts[:classification]
  end
  
  def id
    @id
  end
  
  def self.table_name
    'robots'
  end
end

class Factory
  extend ModelFactory

  default Robot, {
    :name           => 'Rob',
    :classification => :unknown,
  }
end

class RobotSet < ModelSet
end

class << Test::Unit::TestCase
  def test(name, &block)
    test_name = "test_#{name.gsub(/[\s\W]/,'_')}"
    raise ArgumentError, "#{test_name} is already defined" if self.instance_methods.include? test_name
    define_method test_name, &block
  end
end

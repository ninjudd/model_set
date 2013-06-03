require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'mocha/setup'
require 'pp'

require 'model_set'

class Test::Unit::TestCase
end

ActiveRecord::Base.establish_connection(
  :adapter  => "postgresql",
  :host     => "localhost",
  :database => "model_set_test"
)
ActiveRecord::Migration.verbose = false
ActiveRecord::Base.connection.client_min_messages = 'panic'

require 'test_helper'

class MultiSetTest < Test::Unit::TestCase
  class CreateTables < ActiveRecord::Migration    
    def self.up
      create_table :robots do |t|
        t.string :name
        t.string :classification
      end
    end

    def self.down
      drop_table :robots
    end
  end

  class Robot < ActiveRecord::Base
  end

  class RobotSet < ModelSet
  end

  context 'with a db connection' do
    setup do
      CreateTables.verbose = false
      CreateTables.up

      @bender       = Robot.create(:name => 'Bender',     :classification => :smart_ass )
      @r2d2         = Robot.create(:name => 'R2D2',       :classification => :droid     )
      @c3po         = Robot.create(:name => 'C3PO',       :classification => :droid     )
      @rosie        = Robot.create(:name => 'Rosie',      :classification => :domestic  )
      @small_wonder = Robot.create(:name => 'Vicki',      :classification => :child     )
      @t1000        = Robot.create(:name => 'Terminator', :classification => :assasin   )
      @johnny5      = Robot.create(:name => 'Johnny 5',   :classification => :miltary   )
      @data         = Robot.create(:name => 'Data',       :classification => :positronic)
      @number8      = Robot.create(:name => 'Boomer',     :classification => :cylon     )
    end
  
    teardown do
      CreateTables.down
    end
  
    should "add, subtract, intersect" do
      set = MultiSet.new
      set += RobotSet.new([@bender, @r2d2, @rosie])
      set += RobotSet.new([@c3po, @r2d2, @t1000])
      set += RobotSet.new([@data, @number8, @johnny5])
      
      assert_equal [3,3,3], set.size
      assert_equal [@bender,@r2d2,@rosie,@c3po,@t1000,@data,@number8,@johnny5].collect {|r| r.id}, set.ids
      assert_equal [@bender,@r2d2,@rosie,@c3po,@r2d2,@t1000,@data,@number8,@johnny5], set.to_a
      
      set -= RobotSet.new([@r2d2, @rosie, @t1000, @johnny5])
      
      assert_equal [1,1,2], set.size
      assert_equal [@bender,@c3po,@data,@number8].collect {|r| r.id}, set.ids
      
      other_set = MultiSet.new(RobotSet.new([@data]), RobotSet.new([@bender]))
      
      set &= other_set
      assert_equal [1,0,1], set.size
      assert_equal [@bender,@data].collect {|r| r.id}, set.ids    
    end
  end
end

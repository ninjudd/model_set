require File.dirname(__FILE__) + '/test_helper'

class ModelSetTest < Test::Unit::TestCase
  
  def setup_robots
    @bender       = Factory.new_robot(:name => 'Bender',     :classification => :smart_ass )
    @r2d2         = Factory.new_robot(:name => 'R2D2',       :classification => :droid     )
    @c3po         = Factory.new_robot(:name => 'C3PO',       :classification => :droid     )
    @rosie        = Factory.new_robot(:name => 'Rosie',      :classification => :domestic  )
    @small_wonder = Factory.new_robot(:name => 'Vicki',      :classification => :child     )
    @t1000        = Factory.new_robot(:name => 'Terminator', :classification => :assasin   )
    @johnny5      = Factory.new_robot(:name => 'Johnny 5',   :classification => :miltary   )
  
    @bot_set = RobotSet.new([@bender,@r2d2,@c3po,@rosie,@small_wonder,@t1000,@johnny5])

    @data    = Factory.new_robot(:name => 'Data',       :classification => :positronic)
    @number8 = Factory.new_robot(:name => 'Boomer',     :classification => :cylon     )
  end
  
  test "empty" do
    setup_robots

    set = RobotSet.empty
    assert_equal 0, set.size
    assert set.empty?

    set = RobotSet.new(@bender)
    assert !set.empty?
  end

  test "set with single model" do
    setup_robots
    set = RobotSet.new(@bender)
    assert_equal [@bender.id], set.ids
  end

  test "include?" do
    setup_robots
    set = RobotSet.new([@bender, @r2d2.id, @c3po.id])
    assert set.include?(@bender)
    assert set.include?(@r2d2.id)
  end

  test "delete" do
    setup_robots
    set = RobotSet.new([@rosie, @small_wonder, @c3po])
    
    set.delete(@c3po)
    assert_equal [@rosie.id, @small_wonder.id], set.ids
    
    set.delete(@rosie.id)
    assert_equal [@small_wonder.id], set.ids

    set.delete(@small_wonder)
    assert_equal [], set.ids
    assert set.empty?
  end

  test "select" do
    setup_robots
    assert_equal [@r2d2, @c3po], @bot_set.select {|bot| bot.classification == :droid}.to_a
    assert_equal 7, @bot_set.size
    
    @bot_set.select! {|bot| bot.classification == :miltary}
    assert_equal [@johnny5], @bot_set.to_a 
  end

  test "sort" do
    setup_robots
    assert_equal [@bender,@c3po,@johnny5,@r2d2,@rosie,@t1000,@small_wonder], @bot_set.sort {|a,b| a.name <=> b.name}.to_a
    assert_equal @johnny5, @bot_set.last

    @bot_set.sort! {|a,b| b.name <=> a.name}
    assert_equal [@bender,@c3po,@johnny5,@r2d2,@rosie,@t1000,@small_wonder].reverse, @bot_set.to_a 
  end

  test "sort_by" do
    setup_robots
    assert_equal [@bender,@c3po,@johnny5,@r2d2,@rosie,@t1000,@small_wonder], @bot_set.sort_by {|bot| bot.name}.to_a
  end

  test "reject" do
    setup_robots
    @bot_set.reject! {|bot| bot.classification == :domestic}
    assert !@bot_set.include?(@rosie)
  end

  test "set operators" do
    setup_robots
    
    droids    = RobotSet.new([@c3po, @r2d2])
    womanoids = RobotSet.new([@rosie, @small_wonder, @number8])
    humanoids = RobotSet.new([@small_wonder, @t1000, @data, @number8])
    metalics  = RobotSet.new([@r2d2, @c3po, @johnny5])
    cartoons  = RobotSet.new([@bender, @rosie])

    assert_equal ['C3PO', 'R2D2', 'Johnny 5'],                    (droids + metalics).collect {|bot| bot.name}
    assert_equal ['Bender', 'Rosie', 'C3PO', 'R2D2', 'Johnny 5'], (cartoons + droids + metalics).collect {|bot| bot.name}
    assert_equal 5, (cartoons + droids + metalics).size
    assert_equal 5, (cartoons + droids + metalics).count
    
    assert_equal [],                     (droids - metalics).collect {|bot| bot.name}
    assert_equal ['Johnny 5'],           (metalics - droids).collect {|bot| bot.name}
    assert_equal ['Terminator', 'Data'], (humanoids - womanoids).collect {|bot| bot.name}
    assert_equal ['Bender'],             (cartoons - womanoids).collect {|bot| bot.name}
    assert_equal 2, (humanoids - womanoids).size
    assert_equal 2, (humanoids - womanoids).count

    assert_equal ['C3PO', 'R2D2'],    (droids & metalics).collect {|bot| bot.name}
    assert_equal ['R2D2', 'C3PO'],    (metalics & droids).collect {|bot| bot.name}
    assert_equal ['Vicki', 'Boomer'], (humanoids & womanoids).collect {|bot| bot.name}
    assert_equal ['Rosie'],           (cartoons & womanoids).collect {|bot| bot.name}
    assert_equal 2, (humanoids & womanoids).size
    assert_equal 2, (humanoids & womanoids).count

    set = (droids + @johnny5)
    assert_equal ['C3PO', 'R2D2', 'Johnny 5'], set.collect {|bot| bot.name}
    set -= @r2d2
    assert_equal ['C3PO', 'Johnny 5'], set.collect {|bot| bot.name}
  end
    
  test "clone" do
    set     = RobotSet.new([1])
    new_set = set.clone
    assert new_set.object_id != set.object_id
  end
    
end

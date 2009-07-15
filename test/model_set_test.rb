require File.dirname(__FILE__) + '/test_helper'

class ModelSetTest < Test::Unit::TestCase
  class CreateTables < ActiveRecord::Migration    
    def self.up
      create_table :heroes do |t|
        t.column :name, :string
        t.column :universe, :string
      end

      create_table :superpowers do |t|
        t.column :name, :string
      end

      create_table :mutations do |t|
        t.column :name, :string
      end

      create_table :superpets do |t|
        t.column :name, :string
        t.column :species, :string
        t.column :owner_id, :bigint
      end

      create_table :hero_superpowers do |t|
        t.column :hero_id,    :bigint
        t.column :power_type, :string
        t.column :power_id,   :bigint
      end

      create_table :hero_birthdays do |t|
        t.column :hero_id, :bigint
        t.column :birthday, :date
      end

      create_table :robots do |t|
        t.string :name
        t.string :classification
      end
    end

    def self.down
      drop_table :heroes
      drop_table :superpowers
      drop_table :mutations
      drop_table :superpets
      drop_table :hero_superpowers
      drop_table :hero_birthdays
      drop_table :robots
    end
  end
  
  class Superpower < ActiveRecord::Base
  end

  class Mutation < ActiveRecord::Base
  end

  class Superpet < ActiveRecord::Base
  end

  class HeroSuperpower < ActiveRecord::Base
  end

  class Hero < ActiveRecord::Base
    set_table_name 'heroes'
    has_set :superpowers, :through => :hero_superpowers, :other_key => :power_id
    has_set :pets, :class_name => 'Superpet', :own_key => :owner_id do
      def dogs!
        add_conditions!("species = 'dog'")
      end
    end
  end
  
  class HeroSet < ModelSet
    constructor  :with_universe
    clone_method :with_universe
    def with_universe!(universe)
      add_conditions!("universe = '#{universe}'")
    end    

    clone_method :add_birthday
    def add_birthday!
      add_fields!( "hero_birthdays.birthday" => "LEFT OUTER JOIN hero_birthdays ON heroes.id = hero_birthdays.hero_id" )
    end
  end

  context 'with a db connection' do
    setup do
      CreateTables.verbose = false
      CreateTables.up
    end
  
    teardown do
      CreateTables.down
    end
  
    should "construct a model set" do
      captain  = Hero.create(:name => 'Captain America', :universe => 'Marvel')
      spidey   = Hero.create(:name => 'Spider Man',      :universe => 'Marvel')
      batman   = Hero.create(:name => 'Batman',          :universe => 'D.C.'  )
      superman = Hero.create(:name => 'Superman',        :universe => 'D.C.'  )
      ironman  = Hero.create(:name => 'Iron Man',        :universe => 'Marvel')
      
      set = HeroSet.with_universe('Marvel')
      assert_equal [captain.id, spidey.id, ironman.id], set.ids
    end

    should "maintain initial order when adding conditions" do
      captain  = Hero.create(:name => 'Captain America', :universe => 'Marvel')
      spidey   = Hero.create(:name => 'Spider Man',      :universe => 'Marvel')
      batman   = Hero.create(:name => 'Batman',          :universe => 'D.C.'  )
      superman = Hero.create(:name => 'Superman',        :universe => 'D.C.'  )
      ironman  = Hero.create(:name => 'Iron Man',        :universe => 'Marvel')

      set = HeroSet.new([ironman, captain, superman, spidey, batman])

      set.add_conditions!("universe = 'Marvel'")

      assert_equal [ironman.id, captain.id, spidey.id], set.ids
    end

    should "order and reverse set" do
      captain   = Hero.create(:name => 'Captain America', :universe => 'Marvel')
      spidey    = Hero.create(:name => 'Spider Man',      :universe => 'Marvel')
      wolverine = Hero.create(:name => 'Wolverine',       :universe => 'Marvel'  )
      phoenix   = Hero.create(:name => 'Phoenix',         :universe => 'Marvel'  )
      ironman   = Hero.create(:name => 'Iron Man',        :universe => 'Marvel')
      
      ids = [captain.id, ironman.id, phoenix.id, spidey.id, wolverine.id]
      set = HeroSet.with_universe('Marvel')

      set.order_by!('name')
      assert_equal ids, set.ids

      set.reverse!
      assert_equal ids.reverse, set.ids

      set.order_by!('name DESC')
      assert_equal ids.reverse, set.ids

      set.reverse!
      assert_equal ids, set.ids

      # Make sure that a comma in a function call works.
      set.order_by!("lower(ltrim(name, 'C'))")
      assert_equal ids, set.ids

      set.reverse!
      assert_equal ids.reverse, set.ids
    end

    should "have missing ids" do
      missing_id = 5555
      spidey = Hero.create(:name => 'Spider Man', :universe => 'Marvel')
      set = HeroSet.new([spidey.id, missing_id])
      
      # Iterate through the profiles so the missing ones will be detected.
      set.each {}
      assert_equal [missing_id], set.missing_ids
    end
  
    should "have missing ids with add_fields" do
      missing_id = 5555
      spidey = Hero.create(:name => 'Spider Man', :universe => 'Marvel')
      set = HeroSet.new([spidey.id, missing_id]).add_birthday
      
      # Iterate through the profiles so the missing ones will be detected.
      set.each {}
      assert_equal [missing_id], set.missing_ids
    end
  
    should "support has_set" do
      hero = Hero.create(:name => 'Mr. Invisible')
      mighty_mouse = Superpet.create(:name => 'Mighty Mouse', :owner_id => hero.id)
      underdog     = Superpet.create(:name => 'Underdog', :owner_id => hero.id)
      
      set = hero.pets
      assert_equal SuperpetSet, set.class
      assert_equal [mighty_mouse.id, underdog.id], set.ids
    end
    
    should "support has_set with through" do
      hero = Hero.create(:name => 'Mr. Invisible')
      invisibility = Superpower.create(:name => 'Invisibility')
      flying       = Superpower.create(:name => 'Flying')
      HeroSuperpower.create(:hero_id => hero.id, :power_id => invisibility.id)
      HeroSuperpower.create(:hero_id => hero.id, :power_id => flying.id)
      
      set = hero.superpowers
      assert_equal SuperpowerSet, set.class
      assert_equal [invisibility.id, flying.id], set.ids
    end
  
    should "allow set extensions" do
      hero = Hero.create(:name => 'Mr. Invisible')
      mighty_mouse = Superpet.create(:name => 'Mighty Mouse', :owner_id => hero.id, :species => 'mouse')
      sammy        = Superpet.create(:name => 'Sammy Davis Jr. Jr.', :owner_id => hero.id, :species => 'dog')
      underdog     = Superpet.create(:name => 'Underdog', :owner_id => hero.id, :species => 'dog')
      
      set = hero.pets
      assert_equal ['mouse', 'dog', 'dog'], set.collect {|pet| pet.species}
      
      assert_equal [sammy.id, underdog.id], set.dogs!.ids
    end

    class Robot < ActiveRecord::Base
    end
    
    class RobotSet < ModelSet
    end

    setup do
      @bender       = Robot.create(:name => 'Bender',     :classification => :smart_ass )
      @r2d2         = Robot.create(:name => 'R2D2',       :classification => :droid     )
      @c3po         = Robot.create(:name => 'C3PO',       :classification => :droid     )
      @rosie        = Robot.create(:name => 'Rosie',      :classification => :domestic  )
      @small_wonder = Robot.create(:name => 'Vicki',      :classification => :child     )
      @t1000        = Robot.create(:name => 'Terminator', :classification => :assasin   )
      @johnny5      = Robot.create(:name => 'Johnny 5',   :classification => :miltary   )
      
      @bot_set = RobotSet.new([@bender,@r2d2,@c3po,@rosie,@small_wonder,@t1000,@johnny5])
      
      @data    = Robot.create(:name => 'Data',       :classification => :positronic)
      @number8 = Robot.create(:name => 'Boomer',     :classification => :cylon     )
    end
  
    should "be empty" do
      set = RobotSet.empty
      assert_equal 0, set.size
      assert set.empty?
      
      set = RobotSet.new(@bender)
      assert !set.empty?
    end

    should "create a set with single model" do
      set = RobotSet.new(@bender)
      assert_equal [@bender.id], set.ids
    end

    should "include models" do
      set = RobotSet.new([@bender, @r2d2.id, @c3po.id])
      assert set.include?(@bender)
      assert set.include?(@r2d2.id)
      assert set.include?(@c3po)
    end

    should "delete models from a set" do
      set = RobotSet.new([@rosie, @small_wonder, @c3po])
      
      set.delete(@c3po)
      assert_equal [@rosie.id, @small_wonder.id], set.ids
      
      set.delete(@rosie.id)
      assert_equal [@small_wonder.id], set.ids
      
      set.delete(@small_wonder)
      assert_equal [], set.ids
      assert set.empty?
    end

    should "select models from a set" do
      assert_equal [@r2d2, @c3po], @bot_set.select {|bot| bot.classification == :droid}.to_a
      assert_equal 7, @bot_set.size
      
      @bot_set.select! {|bot| bot.classification == :miltary}
      assert_equal [@johnny5], @bot_set.to_a 
    end
    
    should "sort a set" do
      assert_equal [@bender,@c3po,@johnny5,@r2d2,@rosie,@t1000,@small_wonder], @bot_set.sort {|a,b| a.name <=> b.name}.to_a
      assert_equal @johnny5, @bot_set.last
      
      @bot_set.sort! {|a,b| b.name <=> a.name}
      assert_equal [@bender,@c3po,@johnny5,@r2d2,@rosie,@t1000,@small_wonder].reverse, @bot_set.to_a 

      @bot_set.reverse!
      assert_equal [@bender,@c3po,@johnny5,@r2d2,@rosie,@t1000,@small_wonder], @bot_set.to_a 
    end
    
    should "sort a set by name" do
      assert_equal [@bender,@c3po,@johnny5,@r2d2,@rosie,@t1000,@small_wonder], @bot_set.sort_by {|bot| bot.name}.to_a
    end
    
    should "reject models from a set" do
      @bot_set.reject! {|bot| bot.classification == :domestic}
      assert !@bot_set.include?(@rosie)
    end

    should "do set arithmetic" do
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
    
    should "clone a set" do
      set     = RobotSet.new([1])
      new_set = set.clone
      assert new_set.object_id != set.object_id
    end
  end
end

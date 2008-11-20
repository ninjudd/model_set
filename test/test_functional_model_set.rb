require File.dirname(__FILE__) + '/test_helper'

module FunctionalModelSetTest
  ActiveRecord::Base.establish_connection(
    :adapter  => "postgresql",
    :host     => "localhost",
    :username => "postgres",
    :password => "",
    :database => "model_set_test"
  )

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
    end

    def self.down
      drop_table :heroes
      drop_table :superpowers
      drop_table :mutations
      drop_table :superpets
      drop_table :hero_superpowers
      drop_table :hero_birthdays
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

  class ModelSetTest < Test::Unit::TestCase
    def setup
      CreateTables.verbose = false
      CreateTables.up
    end
    
    def teardown
      CreateTables.down
    end

    test "constructor" do
      captain  = Hero.create(:name => 'Captain America', :universe => 'Marvel')
      spidey   = Hero.create(:name => 'Spider Man',      :universe => 'Marvel')
      batman   = Hero.create(:name => 'Batman',          :universe => 'D.C.'  )
      superman = Hero.create(:name => 'Superman',        :universe => 'D.C.'  )
      ironman  = Hero.create(:name => 'Iron Man',        :universe => 'Marvel')
            
      set = HeroSet.with_universe('Marvel')
      assert_equal [captain.id, spidey.id, ironman.id], set.ids
    end

    test "missing_ids" do
      missing_id = 5555
      spidey = Hero.create(:name => 'Spider Man', :universe => 'Marvel')
      set = HeroSet.new([spidey.id, missing_id])

      # Iterate through the profiles so the missing ones will be detected.
      set.each {}
      assert_equal [missing_id], set.missing_ids
    end

    test "missing_ids with add_fields" do
      missing_id = 5555
      spidey = Hero.create(:name => 'Spider Man', :universe => 'Marvel')
      set = HeroSet.new([spidey.id, missing_id]).add_birthday

      # Iterate through the profiles so the missing ones will be detected.
      set.each {}
      assert_equal [missing_id], set.missing_ids
    end

    test "has_set through" do
      hero = Hero.create(:name => 'Mr. Invisible')
      invisibility = Superpower.create(:name => 'Invisibility')
      flying       = Superpower.create(:name => 'Flying')
      HeroSuperpower.create(:hero_id => hero.id, :power_id => invisibility.id)
      HeroSuperpower.create(:hero_id => hero.id, :power_id => flying.id)

      set = hero.superpowers
      assert_equal SuperpowerSet, set.class
      assert_equal [invisibility.id, flying.id], set.ids
    end

    test "has_set" do
      hero = Hero.create(:name => 'Mr. Invisible')
      mighty_mouse = Superpet.create(:name => 'Mighty Mouse', :owner_id => hero.id)
      underdog     = Superpet.create(:name => 'Underdog', :owner_id => hero.id)
      
      set = hero.pets
      assert_equal SuperpetSet, set.class
      assert_equal [mighty_mouse.id, underdog.id], set.ids
    end
    
    test "set extensions" do
      hero = Hero.create(:name => 'Mr. Invisible')
      mighty_mouse = Superpet.create(:name => 'Mighty Mouse', :owner_id => hero.id, :species => 'mouse')
      sammy        = Superpet.create(:name => 'Sammy Davis Jr. Jr.', :owner_id => hero.id, :species => 'dog')
      underdog     = Superpet.create(:name => 'Underdog', :owner_id => hero.id, :species => 'dog')
      
      set = hero.pets
      assert_equal ['mouse', 'dog', 'dog'], set.collect {|pet| pet.species}
      assert_equal [sammy.id, underdog.id], set.dogs!.ids
    end
  end
end

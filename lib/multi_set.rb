class MultiSet
  include Enumerable
  deep_clonable
  
  attr_accessor :sets
  
  def initialize(*sets)
    @sets = sets
  end
  
  def add!(other)
    if other.kind_of?(MultiSet)
      sets.concat(other.sets)
    else
      sets << other
    end
    self
  end

  alias << add!
  
  def method_missing(method_name, *args)
    method_name = method_name.to_s
    if method_name =~ /\!$/
      sets.each do |set|
        set.send(method_name, *args)
      end
      self 
    else
      sets.collect do |set|
        set.send(method_name, *args)
      end
    end
  end
  
  def ids_by_class
    ids_by_class = {}
    sets.each do |set|
      ids_by_class[set.model_class] ||= OrderedSet.new
      ids_by_class[set.model_class].concat(set.ids)
    end
    ids_by_class.keys.each do |model_class|
      ids_by_class[model_class] = ids_by_class[model_class].to_a
    end
    ids_by_class
  end
  
  def ids
    ids = OrderedSet.new
    sets.each do |set|
      ids.concat(set.ids)
    end
    ids.to_a
  end
  
  def each
    sets.each do |set|
      set.each do |model|
        yield model
      end
    end
  end
  
  clone_method :+, :add!
  clone_method :-, :subtract!
  clone_method :&, :intersect!
end

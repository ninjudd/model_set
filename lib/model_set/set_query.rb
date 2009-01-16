class ModelSet
  class SetQuery < Query
    delegate :add!, :unshift!, :subtract!, :intersect!, :reorder!, :to => :set

    def anchor!(query)
      @set = query.ids.to_ordered_set
    end

    def set
      @set ||= [].to_ordered_set
    end

    def ids
      if limit
        set.limit(limit, offset)
      else
        set.clone
      end
    end
    
    def size
      if limit
        [count - offset, limit].min
      else
        count
      end
    end

    def count
      set.size
    end
    
  end
end

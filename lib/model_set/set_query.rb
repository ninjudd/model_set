class ModelSet
  class SetQuery < Query
    delegate :add!, :subtract!, :intersect!, :reorder!, :to => :set

    def anchor!(query, opts = {})
      @set = query.ids(opts).to_ordered_set
    end

    def set
      @set ||= [].to_ordered_set
    end

    def ids(opts = {})      
      limit, offset = limit_and_offset(opts)
      if limit
        set.limit(limit, offset)
      else
        set.clone
      end
    end
    
    def count
      set.size
    end
  end
end

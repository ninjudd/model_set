class ModelSet
  class RawQuery < Query
    attr_reader :records

    def anchor!(query, raw_method = 'find_raw_by_id')
      @records = model_class.send(raw_method, query.ids.to_a)
    end

    def select!(&block)
      records.select!(&block)
    end

    def reject!(&block)
      records.reject!(&block)
    end

    def sort_by!(&block)
      @records = records.sort_by(&block)
    end

    def ids
      if limit
        records[offset, limit].collect {|r| r['id'].to_i}
      else
        records.collect {|r| r['id'].to_i}
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
      records.size
    end
  end
end

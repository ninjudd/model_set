class ModelSet
  class SphinxQuery < Query
    MAX_SPHINX_RESULTS = 1000

    attr_reader :conditions, :filters

    def anchor!(query)
      add_filters!( id_field => query.ids.to_a )
    end    

    def add_filters!(filters)
      @filters ||= {}
      @filters.merge!(filters)
      clear_cache!
    end

    def add_conditions!(conditions)
      @conditions ||= []
      @conditions << conditions
      @conditions.uniq!
      clear_cache!
    end

    def order_by!(field, mode = :ascending)
      raise "invalid mode: :#{mode}" unless [:ascending, :descending].include?(mode)
      @sort_order = [mode, field]
      clear_cache!
    end

    def limit!(limit)
      @limit  = limit  ? limit.to_i  : nil
      clear_limited_cache!
    end

    def size
      fetch_results if @size.nil?
      @size
    end

    def count
      fetch_results if @count.nil?
      @count
    end

    def ids
      fetch_results if @ids.nil?
      @ids
    end

  private

    def fetch_results
      opts = {
        :raw_query   => conditions_clause,
        :class_names => model_name,
      }
      opts[:filters] = @filters if @filters

      if @sort_order
        opts[:sort_mode], opts[:sort_by] = @sort_order
      end

      if limit
        opts[:per_page] = limit
        opts[:page]     = page
      else
        opts[:per_page] = MAX_SPHINX_RESULTS
      end

      if opts[:filters] and opts[:filters][id_field] and opts[:filters][id_field].empty?
        @count = 0
        @size  = 0
        @ids   = []
      else
        before_query(opts)
        search = Ultrasphinx::Search.new(opts)
        
        begin
          search.run(false) # only fetch ids
        rescue Exception => e
          on_exception(e, opts)
        end
        
        @count = search.total_entries
        @size  = search.size
        @ids   = search.results.collect {|model_name, id| id.to_i}.to_ordered_set
        
        after_query(opts)
      end
    end
    
    def conditions_clause
      @conditions ? @conditions.join(' ') : ''
    end
  end
end

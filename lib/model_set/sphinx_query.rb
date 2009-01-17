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

    SORT_MODES = {
      :relevance  => Sphinx::Client::SPH_SORT_RELEVANCE,
      :descending => Sphinx::Client::SPH_SORT_ATTR_DESC,
      :ascending  => Sphinx::Client::SPH_SORT_ATTR_ASC,
      :time       => Sphinx::Client::SPH_SORT_TIME_SEGMENTS,
      :extending  => Sphinx::Client::SPH_SORT_EXTENDED,
      :expression => Sphinx::Client::SPH_SORT_EXPR,
    }

    def order_by!(field, mode = :ascending)
      raise "invalid mode: :#{mode}" unless SORT_MODES[mode]
      @sort_order = [SORT_MODES[mode], field.to_s]
      clear_cache!
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
      if @filters and @filters[id_field] and @filters[id_field].empty?
        @count = 0
        @size  = 0
        @ids   = []
      else
        search = Sphinx::Client.new
        
        # Basic options
        search.SetServer(server_host, server_port)

        search.SetMatchMode(Sphinx::Client::SPH_MATCH_EXTENDED2)
        if limit
          search.SetLimits(offset, limit, offset + limit)
        else
          search.SetLimits(0, MAX_SPHINX_RESULTS, MAX_SPHINX_RESULTS)
        end

        search.SetSortMode(*@sort_order) if @sort_order

        search.SetFilter('class_id', sphinx_class_id)

        @filters and @filters.each do |field, value|
          exclude = defined?(AntiObject) && value.kind_of?(AntiObject)
          value = ~value if exclude

          if value.kind_of?(Range)
            min, max = filter_values([value.begin, value.end])
            search.SetFilterRange(field.to_s, min, max, exclude)
          else
            search.SetFilter(field.to_s, filter_values(value), exclude)
          end
        end

        opts = {
          :query   => conditions_clause,
          :filters => @filters,
        }
        before_query(opts)

        begin
          response = search.Query(opts[:query])
        rescue Exception => e
          on_exception(e, opts)
        end
        
        @count = response['total_found']
        @ids   = response['matches'].collect {|r| r['id']}.to_ordered_set
        @size  = @ids.size
        
        after_query(opts)
      end
    end
    
    def filter_values(values)
      Array(values).collect do |value|
        value.kind_of?(Date) ? value.to_time.to_i : value.to_i
      end
    end

    def sphinx_class_id
      Ultrasphinx::Search::MODELS_TO_IDS[model_class.to_s] || 
      Ultrasphinx::Search::MODELS_TO_IDS[model_class.base_class.to_s]
    end

    def server_host
      Ultrasphinx::CLIENT_SETTINGS['server_host']
    end
    
    def server_port
      Ultrasphinx::CLIENT_SETTINGS['server_port']
    end

    def conditions_clause
      @conditions ? @conditions.join(' ') : ''
    end
  end
end

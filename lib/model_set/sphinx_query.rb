require File.dirname(__FILE__) + '/../../vendor/sphinx_client/lib/sphinx'

class ModelSet
  class SphinxQuery < Query
    MAX_SPHINX_RESULTS = 1000
    MAX_QUERY_TIME = 5000 # milliseconds

    class SphinxError < StandardError; end

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
      if conditions.kind_of?(Hash)
        conditions.each do |field, value|
          next if value.nil?
          field = field.join(',') if field.kind_of?(Array)
          add_conditions!("@(#{field}) #{value}")
        end
      else
        @conditions ||= []
        @conditions << conditions
        @conditions.uniq!
        clear_cache!
      end
    end

    def index
      @index ||= '*'
    end

    def use_index!(index)
      @index = index
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
      if @conditions.nil? or (@filters and @filters[id_field] and @filters[id_field].empty?)
        @count = 0
        @size  = 0
        @ids   = []
      else
        opts = {
          :filters => @filters,
          :query   => conditions_clause,
        }
        before_query(opts)

        search = Sphinx::Client.new
        search.SetMaxQueryTime(MAX_QUERY_TIME)
        search.SetServer(self.class.server_host, self.class.server_port)
        search.SetMatchMode(Sphinx::Client::SPH_MATCH_EXTENDED2)
        if limit
          search.SetLimits(offset, limit, offset + limit)
        else
          search.SetLimits(0, MAX_SPHINX_RESULTS, MAX_SPHINX_RESULTS)
        end
        search.SetSortMode(*@sort_order) if @sort_order
        search.SetFilter('class_id', model_class.class_id) if model_class.respond_to?(:class_id)

        @filters and @filters.each do |field, value|
          next if value.nil?

          exclude = defined?(AntiObject) && value.kind_of?(AntiObject)
          value = ~value if exclude

          if value.kind_of?(Range)
            min, max = filter_values([value.begin, value.end])
            search.SetFilterRange(field.to_s, min, max, exclude)
          else
            search.SetFilter(field.to_s, filter_values(value), exclude)
          end
        end

        begin
          response = search.Query(opts[:query], index)
          raise SphinxError, search.GetLastError unless response
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
        case value
        when Date       : value.to_time.to_i
        when TrueClass  : 1
        when FalseClass : 0
        else
          value.to_i
        end
      end
    end

    class << self
      attr_accessor :server_host, :server_port
    end

    def conditions_clause
      @conditions ? @conditions.join(' ') : ''
    end
  end
end

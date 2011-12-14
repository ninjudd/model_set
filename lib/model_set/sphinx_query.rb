require File.dirname(__FILE__) + '/../../vendor/sphinx_client/lib/sphinx'
begin
  require 'system_timer'
rescue LoadError => e
  module SystemTimer
    def self.timeout(time, &block)
      Timeout.timeout(time, &block)
    end
  end
end

class ModelSet
  class SphinxQuery < Query
    MAX_SPHINX_RESULTS = 1000
    MAX_QUERY_TIME     = 5

    attr_reader :conditions, :filters

    def max_query_time
      @max_query_time || MAX_QUERY_TIME
    end

    def max_query_time!(seconds)
      @max_query_time = seconds
    end

    def anchor!(query)
      add_filters!( id_field => query.ids.to_a )
    end

    def add_filters!(filters)
      @filters ||= []

      filters.each do |key, value|
        next if value.nil?
        @empty = true if value.kind_of?(Array) and value.empty?
        @filters << [key, value]
      end
      clear_cache!
    end

    def geo_anchor!(opts)
      @geo = opts
    end

    def add_conditions!(conditions)
      if conditions.kind_of?(Hash)
        conditions.each do |field, value|
          next if value.nil?
          field = field.join(',') if field.kind_of?(Array)
          value = "(#{value.join('|')})" if value.kind_of?(Array)
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

    def use_index!(index, opts = {})
      if opts[:delta]
        @index = "#{index} #{index}_delta"
      else
        @index = index
      end
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
      if field == :relevance
        @sort_order = [SORT_MODES[:relevance]]
      else
        raise "invalid mode: :#{mode}" unless SORT_MODES[mode]
        @sort_order = [SORT_MODES[mode], field.to_s]
      end
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

    class SphinxError < StandardError
      attr_accessor :opts
      def message
        "#{super}: #{opts.inspect}"
      end
    end

  private

    def fetch_results
      if @conditions.nil?
        raise ArgumentError.new('No conditions specified')
      elsif @empty
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
        search.SetMaxQueryTime(max_query_time * 1000)
        search.SetServer(self.class.server_host, self.class.server_port)
        search.SetMatchMode(Sphinx::Client::SPH_MATCH_EXTENDED2)
        if limit
          search.SetLimits(offset, limit, offset + limit)
        else
          search.SetLimits(0, MAX_SPHINX_RESULTS, MAX_SPHINX_RESULTS)
        end

        search.SetSortMode(*@sort_order) if @sort_order
        search.SetFilter('class_id', model_class.class_id) if model_class.respond_to?(:class_id)

        if @geo
          # Latitude and longitude in radians, radius in meters.
          lat_field  = @geo[:latitude_field]  || "#{@geo[:prefix]}_latitude"
          long_field = @geo[:longitude_field] || "#{@geo[:prefix]}_longitude"

          search.SetGeoAnchor(lat_field, long_field, @geo[:latitude].to_f, @geo[:longitude].to_f)
          search.SetFloatRange('@geodist', 0.0, @geo[:radius].to_f)
        end

        @filters and @filters.each do |field, value|
          exclude = defined?(AntiObject) && value.kind_of?(AntiObject)
          value = ~value if exclude

          if value.kind_of?(Range)
            min, max = filter_values([value.begin, value.end])
            if min.kind_of?(Float) or max.kind_of?(Float)
              search.SetFilterFloatRange(field.to_s, min.to_f, max.to_f, exclude)
            else
              search.SetFilterRange(field.to_s, min, max, exclude)
            end
          else
            search.SetFilter(field.to_s, filter_values(value), exclude)
          end
        end

        begin
          response = SystemTimer.timeout(max_query_time) do
            search.Query(opts[:query], index)
          end
          unless response
            e = SphinxError.new(search.GetLastError)
            e.opts = opts
            raise e
          end
        rescue Exception => e
          e = SphinxError.new(e) unless e.kind_of?(SphinxError)
          e.opts = opts
          on_exception(e)
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
        when Date       then value.to_time.to_i
        when TrueClass  then 1
        when FalseClass then 0
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

require File.dirname(__FILE__) + '/../../vendor/sphinx_client/lib/sphinx'
require 'system_timer'

class ModelSet
  class SphinxQuery < Query
    include Conditioned

    MAX_RESULTS    = 1000
    MAX_QUERY_TIME = 5

    class << self
      attr_accessor :host, :port
    end
    attr_reader :filters, :response

    def max_query_time
      @max_query_time || MAX_QUERY_TIME
    end

    def max_query_time!(seconds)
      @max_query_time = seconds
    end

    def max_results
      @max_results || MAX_RESULTS
    end

    def max_results!(max)
      @max_results = max
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

    def select_fields!(*fields)
      @select = fields.flatten
    end

    SORT_MODES = {
      :relevance  => Sphinx::Client::SPH_SORT_RELEVANCE,
      :descending => Sphinx::Client::SPH_SORT_ATTR_DESC,
      :ascending  => Sphinx::Client::SPH_SORT_ATTR_ASC,
      :time       => Sphinx::Client::SPH_SORT_TIME_SEGMENTS,
      :extended   => Sphinx::Client::SPH_SORT_EXTENDED,
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

    RANKING_MODES = {
      :proximity_bm25 => Sphinx::Client::SPH_RANK_PROXIMITY_BM25,
      :bm25           => Sphinx::Client::SPH_RANK_BM25,
      :none           => Sphinx::Client::SPH_RANK_NONE,
      :word_count     => Sphinx::Client::SPH_RANK_WORDCOUNT,
      :proximity      => Sphinx::Client::SPH_RANK_PROXIMITY,
      :fieldmask      => Sphinx::Client::SPH_RANK_FIELDMASK,
      :sph04          => Sphinx::Client::SPH_RANK_SPH04,
      :total          => Sphinx::Client::SPH_RANK_TOTAL,
    }

    def rank_using!(mode_or_expr)
      if mode_or_expr.nil?
        @ranking = nil
      elsif mode = RANKING_MODES[mode_or_expr]
        @ranking = [mode]
      else
        @ranking = [Sphinx::Client::SPH_RANK_EXPR, mode_or_expr]
      end
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

    def id_field
      if set_class.respond_to?(:sphinx_id_field)
        set_class.sphinx_id_field
      else
        'id'
      end
    end

    class SphinxError < StandardError
      attr_accessor :opts
      def message
        "#{super}: #{opts.inspect}"
      end
    end

  private

    def fetch_results
      if conditions.nil? or @empty
        @count = 0
        @size  = 0
        @ids   = []
      else
        opts = {
          :filters => @filters,
          :query   => conditions.to_s,
        }
        before_query(opts)

        search = Sphinx::Client.new
        search.SetMaxQueryTime(max_query_time * 1000)
        search.SetServer(self.class.host, self.class.port)
        search.SetSelect((@select || [id_field]).join(','))
        search.SetMatchMode(Sphinx::Client::SPH_MATCH_EXTENDED2)
        if limit
          search.SetLimits(offset, limit, max_results)
        else
          search.SetLimits(0, max_results, max_results)
        end

        search.SetSortMode(*@sort_order) if @sort_order
        search.SetRankingMode(*@ranking) if @ranking
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
          @response = SystemTimer.timeout(max_query_time) do
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
        
        @count = [response['total_found'], max_results].min
        @ids   = response['matches'].collect {|match| set_class.as_id(match[id_field])}.to_ordered_set
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

    def condition_ops
      { :not => '-',
        :and => ' ',
        :or  => '|' }
    end

    def transform_condition(condition)
      if condition.kind_of?(Hash)
        condition.collect do |field, value|
          next if value.nil?
          field = field.join(',') if field.kind_of?(Array)
          if value.kind_of?(Array)
            value = [:or, *value] unless value.first.kind_of?(Symbol)
            value = to_conditions(*value).to_s
          end
          "@(#{field}) #{value}"
        end.compact
      else
        condition
      end
    end
  end
end

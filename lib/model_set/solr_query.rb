require 'rsolr'
require 'json'

class ModelSet
  class SolrQuery < Query
    include Conditioned

    MAX_SOLR_RESULTS = 1000

    class << self
      attr_accessor :host
    end
    attr_reader :response

    def anchor!(query)
      add_conditions!( ids_clause(query.ids) )
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

    def use_core!(core)
      @core = core
    end

    def select_fields!(*fields)
      @select = fields.flatten
    end

  private

    def fetch_results
      params = {:q => "#{conditions.to_s}"}
      params[:fl] = @select || ['id']
      params[:wt] = :json
      if limit
        params[:rows]  = limit
        params[:start] = offset
      else
        params[:rows] = MAX_SOLR_RESULTS
      end

      before_query(params)
      begin
        url = "http://" + self.class.host
        url += "/" + @core if @core
        search = RSolr.connect(:url => url)
        @response = JSON.parse(search.get('select', :params => params))
      rescue Exception => e
        on_exception(e, params)
      end
      after_query(params)

      @count = response['response']['numFound']
      @ids   = response['response']['docs'].collect {|doc| set_class.as_id(doc['id'])}.to_ordered_set
      @size  = @ids.size
    end

    def ids_clause(ids, field = nil)
      return 'pk_i:(false)' if ids.empty?
      field ||= 'pk_i'
      "#{field}:(#{ids.join(' OR ')})"
    end
  end
end

require 'rsolr'

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

    def use_index!(index)
      @index = index
    end

    def select_fields!(*fields)
      @select = fields.flatten
    end

  private

    def fetch_results
      query = "#{conditions.to_s}"
      params = {}
      params[:field_list] = @select || ['id']

      if limit
        params[:rows]  = limit
        params[:start] = offset
      else
        params[:rows] = MAX_SOLR_RESULTS
      end

      before_query(solr_params)
      begin 
        search = RSolr.connect(:url => "http://" + self.class.host)
        @response = search.get(@index, :q => query, :params => params)['response']
      rescue Exception => e
        on_exception(e, solr_params)
      end
      after_query(solr_params)

      @count = @response['numFound']
      @ids   = @response['docs'].collect {|doc| doc['id'].to_i}
      @size  = @ids.size
    end

    def ids_clause(ids, field = nil)
      return 'pk_i:(false)' if ids.empty?
      field ||= 'pk_i'
      "#{field}:(#{ids.join(' OR ')})"
    end
  end
end

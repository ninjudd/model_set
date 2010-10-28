require 'solr'

class ModelSet
  class SolrQuery < Query
    attr_reader :response
    include Conditioned

    MAX_SOLR_RESULTS = 1000

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

    def config(params)
      @config = @config ? @config.merge(params) : params
    end

  private

    def fetch_results
      query = "#{conditions.to_s}"
      solr_params = {:highlighting => {}}

      if limit
        solr_params[:rows]  = limit
        solr_params[:start] = offset
      else
        solr_params[:rows] = MAX_SOLR_RESULTS
      end

      before_query(solr_params)
      begin 
        solr_uri = "http://" + SOLR_HOST 
        if @config[:core]
          solr_uri << "/" + @config[:core]
        end
        @response = Solr::Connection.new(solr_uri).search(query, solr_params)        
      rescue Exception => e
        on_exception(e, solr_params)
      end
      after_query(solr_params)

      @count = @response.total_hits
      @ids   = @response.hits.map{ |hit| hit[@config[:response_id_field]].to_i }
      @size  = @ids.size
    end

    def ids_clause(ids, field = nil)
      return 'pk_i:(false)' if ids.empty?
      field ||= 'pk_i'
      "#{field}:(#{ids.join(' OR ')})"
    end

    def sanitize_condition(condition)
      condition
    end
  end
end

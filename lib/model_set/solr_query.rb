require 'solr'

class ModelSet
  class SolrQuery < Query
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

    def resp
      fetch_results if @resp.nil?
      @resp
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
        @resp = Solr::Connection.new(SOLR_HOST).search(query, solr_params)
      rescue Exception => e
        on_exception(e, solr_params)
      end
      after_query(solr_params)

      @count = @resp.total_hits
      @ids   = @resp.hits.map{ |hit| hit["discussion_id"].to_i }
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

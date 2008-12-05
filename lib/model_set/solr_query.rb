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

  private

    def fetch_results
      query = "#{conditions_clause};#{order_clause}"
      
      RAILS_DEFAULT_LOGGER.c_debug("SOLR QUERY: #{query}")
      
      solr_params = []
      solr_params << "q=#{ ERB::Util::url_encode(query) }"
      solr_params << "wt=ruby"
      solr_params << "fl=pk_i"
      
      if limit
        solr_params << "rows=#{limit}"
        solr_params << "start=#{offset}"
      else
        solr_params << "rows=#{MAX_SOLR_RESULTS}"
      end
      
      solr_params = solr_params.join('&')
      
      # Catch any errors when calling solr so we can log the params.
      begin
        resp = eval ActsAsSolr::Post.execute(solr_params)
      rescue Exception => e
        RAILS_DEFAULT_LOGGER.info("SOLR ERROR: exception: #{e.message}")
        RAILS_DEFAULT_LOGGER.info("SOLR ERROR: solr_params: #{solr_params}")
        # RAILS_DEFAULT_LOGGER.info("SOLR ERROR: backtrace: #{e.backtrace}")
        raise
      end
      
      @count = resp['response']['numFound']
      @ids   = resp['response']['docs'].collect {|doc| doc['pk_i'].to_i}.to_ordered_set
      @size  = @ids.size
    end

    def order_clause
      @sort_order.to_s
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

class ModelSet
  class SolrQuery < ConditionsQuery
    MAX_SOLR_RESULTS = 1000

  def size
    sync if @size.nil?
    @size
  end

  def count
    sync if @size.nil?
    @count
  end

  def aggregate(query)
    raise 'aggregate queries not supported in Solr'
  end

  def self.set_class_suffix
    'SetSolr'
  end

private

  def fetch_model_ids(flag = nil)
    query = "#{conditions_clause};#{order_clause}"

    RAILS_DEFAULT_LOGGER.c_debug("SOLR QUERY: #{query}")

    solr_params = []
    solr_params << "q=#{ ERB::Util::url_encode(query) }"
    solr_params << "wt=ruby"
    solr_params << "fl=pk_i"

    if flag == :limited
      solr_params << "rows=#{@limit}"
      solr_params << "start=#{@offset}"
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
    ids    = resp['response']['docs'].collect {|doc| doc['pk_i']}
    @size  = ids.size

    if flag == :limited
      @limited_model_ids = ids.to_ordered_set
    end

    if @size == @count or flag != :limited
      @model_ids = ids.to_ordered_set
    end
  end

  def fetch_limited_model_ids
    fetch_model_ids(:limited)
  end

  def order_clause
    @sort_order.to_s
  end

  def in_query(ids, field = nil)
    return 'pk_i:(false)' if ids.empty?
    field ||= 'pk_i'
    "#{field}:(#{ids.join(' OR ')})"
  end

  def sanitize(query)
    query
  end
end

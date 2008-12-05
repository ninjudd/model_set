class ModelSetSphinx < ModelSet
  MAX_SPHINX_RESULTS = 1000

  def add_joins!(*joins)
    raise 'joins not supported in Sphinx'
  end

  def add_filters!(filters)
    @filters ||= {}
    @filters.merge!(filters)
  end

  def order_by!(field, mode = :ascending)
    raise "invalid mode: :#{mode}" unless [:ascending, :descending].include?(mode)
    @sort_order = [mode, field]
    self
  end

  def unsorted!
    @sort_order = nil
    self
  end

  clone_method :page
  def page!(page)
    # Use @offset for page so reset_conditions! will work since offset isn't supported.
    @offset = page
    clear_limited_id_cache!
    self
  end

  clone_method :limit
  def limit!(limit)
    @limit = limit
    clear_limited_id_cache!
    self
  end

  def size
    sync if @size.nil?
    @size
  end

  def count
    sync if @size.nil?
    @count
  end

  def aggregate(query)
    raise 'aggregate queries not supported in Sphinx'
  end

  def self.set_class_suffix
    'SetSphinx'
  end

  def clone_fields
    super
    @filters = @filters.clone if @filters
  end

private

  def fetch_model_ids(flag = nil)
    opts = {
      :query       => conditions_clause,
      :filters     => @filters,
      :class_names => model_name,
    }

    if @sort_order
      opts[:sort_mode], opts[:sort_by] = @sort_order
    end

    if flag == :limited
      opts[:per_page] = @limit
      opts[:page]     = @offset
    else
      opts[:per_page] = MAX_SPHINX_RESULTS
    end

    RAILS_DEFAULT_LOGGER.c_debug("SPHINX SEARCH: #{opts.inspect}")
    search = Ultrasphinx::Search.new(opts)

    begin
      search.run(false)
    rescue Exception => e
      RAILS_DEFAULT_LOGGER.info("SPHINX ERROR: exception: #{e.message}")
      RAILS_DEFAULT_LOGGER.info("SPHINX ERROR: params: #{opts.inspect}")
      # RAILS_DEFAULT_LOGGER.info("SPHINX ERROR: backtrace: #{e.backtrace}")
      raise
    end
        
    @count = search.total_entries
    @size  = search.size
    ids    = search.results.collect {|model_name, id| id}

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

  def in_query(ids, field = nil)
    raise 'in_query not supported in Sphinx'
  end

  def sanitize_conditions(conditions)
    conditions
  end
end

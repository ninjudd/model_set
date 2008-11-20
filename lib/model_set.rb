require 'rubygems'
require 'active_record'
require 'deep_clonable'
require 'ordered_set'
require File.dirname(__FILE__) + '/multi_set'

class ModelSet
  VERSION = "0.8.0"

  include Enumerable
  include ActiveSupport::CoreExtensions::Array::Conversions

  deep_clonable

  MAX_CACHE_SIZE = 1000 if not defined?(MAX_CACHE_SIZE)

  def initialize(models)
    if models.kind_of?(self.class)
      self.ids      = models.ids.to_ordered_set
      @models_by_id = models.models_by_id
    elsif models
      self.ids = as_ids(models)
    end
  end

  def ids
    if limit?
      limited_model_ids.to_a
    else
      model_ids.to_a
    end
  end

  def missing_ids
    ( @missing_ids || [] ).uniq
  end

  ACTION_TO_OPERATOR = {
    :add!       => :or,
    :subtract!  => :not,
    :intersect! => :and,
  } if not defined?(ACTION_TO_OPERATOR)

  def perform_action!(action, models)
    operator = ACTION_TO_OPERATOR[action.to_sym]
    raise "invalid action #{action}" unless operator

    # FIXME: OR has terrible performance in postgres, so we have to anchor everything for now.
    self.anchor_ids! # FIXME
    if models.kind_of?(self.class)
      models.anchor_ids! # FIXME
      merge_cache!(models) 
      if anchored? and models.anchored?
        # Add together the model ids.
        perform_action!(action, models.ids)
      else
        anchor_sql! if joins?
        
        if models.joins?
          # Cannot combine joins, so we have to get the underlying sql to add a condition.
          sql = models.all_ids_sql
          add_conditions!(operator, "#{prefix(id_field)} IN (#{sql})")
        else
          # Add together the conditions.
          combine_conditions!(operator, models)
        end
      end
    else
      ids = as_ids(models)
      if anchored?
        model_ids.send(action, ids)
        self.ids = model_ids
      else
        add_conditions!(operator, in_query(ids))
      end
    end
    self
  end

  ACTION_TO_OPERATOR.keys.each do |action|
    define_method(action) do |models|
      perform_action!(action, models)
    end
  end

  clone_method :+, :add!
  clone_method :-, :subtract!
  clone_method :&, :intersect!

  alias << add!
  alias concat add!
  alias delete subtract!
  alias without! subtract!
  clone_method :without  

  clone_method :page
  def page!(page = nil)
    raise 'cannot have a page without a limit' if not @limit
    page ||= 1
    @offset = @limit * (page.to_i - 1)
    clear_limited_id_cache!
    self
  end

  clone_method :limit
  def limit!(limit, offset = 0)
    @limit  = limit.to_i unless limit.nil?
    @offset = offset.to_i
    clear_limited_id_cache!
    self
  end

  def include?(model)
    model_id = as_id(model)
    model_ids.include?(model_id)
  end

  def by_id(id)
    return nil if id.nil?
    fetch_models([id]) unless models_by_id[id]
    models_by_id[id] || nil
  end

  # FIXME make work for nested offsets
  def [](*args)
    case args.size
    when 1
      index = args[0]
      if index.kind_of?(Range)
        offset = index.begin
        limit  = index.end - index.begin
        limit += 1 unless index.exclude_end?
        self.limit(limit, offset)
      else
        by_id(ids[index])
      end
    when 2
      offset, limit = args
      self.limit(limit, offset)
    else
      raise ArgumentError.new("wrong number of arguments (#{args.size} for 1 or 2)")
    end
  end
  alias slice []

  def first(limit=nil)
    if limit
      self.limit(limit)
    else
      self[0]
    end
  end

  def last(limit=nil)
    if limit
      self.limit(limit, size - limit)
    else
      self[-1]
    end
  end

  def second
    self[1]
  end

  def in_groups_of(num)
    each_slice(num) do |slice_set|
      slice = slice_set.to_a
      slice[num-1] = nil if slice.size < num
      yield slice
    end
  end

  def each_slice(num=MAX_CACHE_SIZE)
    ids.each_slice(num) do |slice_ids|
      set = self.clone
      set.ids = slice_ids
      set.clear_cache!
      yield set
    end
  end

  def each
    num_models = ids.size
    ids.each_slice(MAX_CACHE_SIZE) do |slice_ids|
      clear_cache! if num_models > MAX_CACHE_SIZE
      fetch_models(slice_ids)
      slice_ids.each do |id|
        # Skip models that aren't in the database.
        model = models_by_id[id]
        if model
          yield model
        else
          ( @missing_ids ||= [] ) << id
        end
      end
    end
  end

  def reject(&block)
    self.clone.reject!(&block)
  end

  def reject!
    filtered_ids = []
    self.each do |model|
      filtered_ids << model.send(id_field) unless yield model
    end
    self.ids = filtered_ids
    self
  end

  def select(&block)
    self.clone.select!(&block)
  end

  def select!
    filtered_ids = []
    self.each do |model|
      filtered_ids << model.send(id_field) if yield model
    end
    self.ids = filtered_ids
    self
  end

  def reject_ids(&block)
    self.clone.select_ids!(&block)
  end

  def reject_ids!
    self.ids = ids.select do |id|
      not yield id
    end
    self
  end

  def select_ids(&block)
    self.clone.select_ids!(&block)
  end

  def select_ids!
    self.ids = ids.select do |id|
      yield id
    end
    self
  end

  def sort(&block)
    self.clone.sort!(&block)
  end

  def sort!(&block)
    block ||= lambda {|a,b| a <=> b}
    self.ids = model_ids.sort do |a,b|
      block.call(by_id(a), by_id(b))
    end
    self
  end

  def sort_by(&block)
    self.clone.sort_by!(&block)
  end

  def sort_by!(&block)
    block ||= lambda {|a,b| a <=> b}
    self.ids = model_ids.sort_by do |id|
      yield by_id(id)
    end
    self
  end

  def partition_by(filter)
    filter = filter.to_s
    filter[-1] = '' if filter =~ /\!$/
    positive = self.send(filter)
    negative = self - positive
    if block_given?
      yield(positive, negative)
    else
      [positive, negative]
    end
  end

  def count
    @count ||= if model_ids_fetched? or not limit?
      model_ids.size
    else
      aggregate("COUNT(DISTINCT #{prefix(id_field)})").to_i
    end
  end

  def size
    @size ||= if limit?
      limited_model_ids.size
    else
      count
    end
  end
  alias length size

  def any?
    return super if block_given?

    @any ||= if limit?
      limited_model_ids.any?
    else 
      count > 0
    end
  end

  def empty?
    not any?
  end

  def empty!
    self.ids = []
    self
  end

  def ids=(model_ids)    
    anchor_ids!(model_ids)
  end

  def anchor_ids!(model_ids = self.ids)
    model_ids.collect! {|id| id.to_i}
    model_ids = model_ids.to_ordered_set
    conditions = in_query(model_ids)

    reset_conditions!(conditions)
    reset_limit!

    @model_ids = model_ids
    @anchored  = true
    self
  end

  def anchor_sql!
    ids = @model_ids
    reset_conditions!("#{prefix(id_field)} IN (#{all_ids_sql})")
    @model_ids = ids
    self
  end

  def anchored?
    @anchored
  end

  def remove_missing!
    clear_id_cache!
    anchor_ids!
  end

  def reorder!(other)
    model_ids.reorder!(as_ids(other))
    anchor_ids!(model_ids)
  end

  def limit?
    not @limit.nil?
  end

  def add_conditions!(*conditions)
    clear_id_cache!

    if conditions.first.kind_of?(Symbol)
      operator = conditions.shift
      raise "invalid operator :#{operator}" unless valid_operator?(operator)
    end
    operator ||= :and

    if operator == :not
      raise 'operator :not is unary; multiple sub-conditions provided' if conditions.size > 1
      invert = true
      operator = :and
    end

    @conditions ||= [operator]
    if @conditions.first != operator
      @conditions = [operator, @conditions]
    end
        
    conditions.each do |condition|
      condition = sanitize(condition)
      if invert
        @conditions << [:not, condition]
      else
        @conditions << condition
      end
    end
    @conditions.uniq!
    self
  end

  def combine_conditions!(operator, other)
    clear_id_cache!

    conditions = other.conditions
    raise "invalid operator :#{operator}" unless valid_operator?(operator)

    # In this case, :not actually means :and :not.
    if operator == :not
      conditions = [:not, conditions]
      operator = :and
    end

    if @conditions.first == operator
      @conditions << conditions
    else
      @conditions = [operator, @conditions, conditions]
    end
  end

  def invert!   
    if @conditions.size == 2 
      if @conditions.first == :not
        if @conditions.last.kind_of?(Array)
          @conditions = @conditions.last
        else
          @conditions = [:and, @conditions.last]
        end
      else
        @conditions = [:not, @conditions.last]
      end
    else
      @conditions = [:not, @conditions]
    end
  end

  def add_joins!(*joins)
    @joins ||= []

    joins.each do |join|
      @joins << sanitize(join)
    end
    @joins.uniq!
    self
  end

  def joins?
    not joins.nil?
  end

  def add_fields!(fields)
    raise 'cannot use both add_fields and include_models' if @included_models

    ( @add_fields ||= {} ).merge!(fields)

    # We have to reload the models because we are adding additional fields.
    self.clear_cache!
  end

  def include_models!(*models)
    raise 'cannot use both add_fields and include_models' if @add_fields

    # included models to pass to find call (see ActiveResource::Base.find)
    ( @included_models ||= [] ).concat(models)

    # We have to reload the models because we are adding additional fields.
    self.clear_cache!
  end

  def order_by!(order, joins = nil)
    @sort_order = order ? order.to_s : nil
    @sort_joins = joins
    clear_id_cache!
    self
  end

  def unsorted!
    order_by!(nil)
  end

  def aggregate(query, opts = {})
    sql = "SELECT #{query} #{from_clause}"
    sql << " LIMIT #{opts[:limit]}"       if opts[:limit]
    sql << " GROUP BY #{opts[:group_by]}" if opts[:group_by]
    result = db.select_rows(sql).first
    result.size == 1 ? result.first : result
  end

  def reset_conditions!(initial_condition = nil)
    @conditions = nil
    @joins      = nil
    @sort_order = nil
    @sort_joins = nil

    if initial_condition
      add_conditions!(initial_condition)
    end
  end

  def reset_limit!
    @limit  = nil
    @offset = nil
  end

  def clear_id_cache!
    @model_ids   = nil
    @count       = nil
    @missing_ids = nil
    @anchored    = false
    clear_limited_id_cache!
  end

  def clear_limited_id_cache!
    @any               = nil
    @size              = nil
    @limited_model_ids = nil
  end

  def clear_cache!
    @models_by_id = nil
    self
  end

  def merge_cache!(other)
    other_cache = other.models_by_id
    models_by_id.merge!(other_cache)
    self
  end

  def sync
    ids
    self
  end

  def sync_models
    if size <= MAX_CACHE_SIZE
      fetch_models(model_ids)
    end
    self
  end

  def clone_fields
    # Do a deep copy of the fields we want to modify.
    @joins             = @joins.clone             if @joins
    @conditions        = @conditions.clone        if @conditions
    @model_ids         = @model_ids.clone         if @model_ids
    @limited_model_ids = @limited_model_ids.clone if @limited_model_ids
    @add_fields        = @add_fields.clone        if @add_fields
    @included_models   = @included_models.clone   if @included_models
  end

  def self.as_set(models)
    models.kind_of?(self) ? models : new(models)
  end

  def self.as_ids(models)
    return [] unless models
    if models.kind_of?(self)
      models.ids
    else
      models = [models] if not models.kind_of?(Enumerable)
      models.collect {|model| model.kind_of?(ActiveRecord::Base) ? model.id : model.to_i }
    end
  end

  def self.empty
    new([])
  end

  def self.all
    new(nil)
  end

  def self.find(opts)
    set = all
    set.add_joins!(opts[:joins])            if opts[:joins]
    set.add_conditions!(opts[:conditions])  if opts[:conditions]
    set.order_by!(opts[:order])             if opts[:order]
    set.limit!(opts[:limit], opts[:offset]) if opts[:limit]
    set.page!(opts[:page])                  if opts[:page]
    set
  end

  def self.find_by_sql(sql)
    set = all
    set.add_conditions!("#{prefix(id_field)} IN (#{sql})")
    set
  end

  def self.constructor(filter_name)
    (class << self; self; end).module_eval do
      define_method filter_name do |*args|
        self.all.send("#{filter_name}!", *args)
      end
    end
  end

  # By default the model class is the set class without the trailing "Set".
  # If you use a different model class you can call "model_class MyModel" in your set class.
  def self.model_class(model_class = nil)
    return ActiveRecord::Base if self == ModelSet

    if model_class.nil?
      @model_class ||= self.name.sub(/#{set_class_suffix}$/,'').constantize
    else
      @model_class = model_class
    end
  end

  def self.set_class_suffix
    'Set'
  end

  def self.table_name(table_name = nil)
    if table_name.nil?
      @table_name ||= model_class.table_name
    else
      @table_name = table_name
    end
  end

  def self.prefix(*fields)
    [*fields].collect do |field|
      "#{table_name}.#{field}"
    end
  end

  def self.id_field(id_field = nil)
    if id_field.nil?
      @id_field ||= 'id'
    else
      @id_field = id_field
    end
  end

  def self.db
    model_class.connection
  end

  def self.postgres?
    defined?(PGconn) and db.raw_connection.is_a?(PGconn)
  end

  def self.in_query(ids, field = nil)
    field ||= prefix(id_field)
    if ids.empty?
      "false"
    elsif postgres?
      "#{field} = ANY ('{#{ids.join(',')}}'::bigint[])"
    else
      "#{field} IN (#{ids.join(',')})"
    end
  end

  # Define instance methods based on class methods.
  [:model_class, :table_name, :prefix, :id_field, :db, :in_query].each do |method|
    define_method(method) do |*args|
      self.class.send(method, *args)
    end
  end

protected
  attr_reader :conditions, :joins

  def models_by_id
    @models_by_id ||= {}
  end

  def model_ids
    if @model_ids.nil?
      fetch_model_ids
    end
    @model_ids
  end
    
  def model_ids_fetched?
    not @model_ids.nil?
  end

  def limited_model_ids
    if @limited_model_ids.nil?
      if model_ids_fetched?
        @limited_model_ids = @model_ids.limit(@limit, @offset)
      else
        fetch_limited_model_ids
      end
    end
    @limited_model_ids
  end
    
  def limited_model_ids_fetched?
    not @limited_model_ids.nil?
  end

  def all_ids_sql
    "#{select_clause} #{from_clause} #{order_clause}"
  end

  def limited_ids_sql
    "#{select_clause} #{from_clause} #{order_clause} #{limit_clause}"
  end

private

  def sanitize(condition)
    ActiveRecord::Base.send(:sanitize_sql, condition)
  end

  def fetch_models(ids_to_fetch)
    ids_to_fetch = ids_to_fetch - models_by_id.keys

    if not ids_to_fetch.empty?
      if @add_fields.nil? and @included_models.nil?
        models = model_class.send("find_all_by_#{id_field}", ids_to_fetch.to_a)
      else
        fields = ["#{table_name}.*"]
        joins  = []
        @add_fields and @add_fields.each do |field, join|
          fields << field
          joins  << join
        end
        joins.uniq!

        models = model_class.find(:all,
          :select     => fields.compact.join(','),
          :joins      => joins.compact.join(' '),
          :conditions => in_query(ids_to_fetch),
          :include    => @included_models
        )
      end
      models.each do |model|
        id = model.send(id_field)
        models_by_id[id] ||= model
      end
    end
  end

  def fetch_model_ids
    selected_ids = db.select_values(all_ids_sql)
    selected_ids.collect! {|id| id.to_i}
    @model_ids = selected_ids.to_ordered_set
  end

  def fetch_limited_model_ids
    selected_ids = db.select_values(limited_ids_sql)
    selected_ids.collect! {|id| id.to_i}
    @limited_model_ids = selected_ids.to_ordered_set
  end

  def select_clause
    "SELECT #{table_name}.#{id_field}"
  end

  def limit_clause
    return unless @limit
    limit = "LIMIT #{@limit}"
    limit << " OFFSET #{@offset}" if @offset > 0
    limit
  end

  def from_clause
    "FROM #{table_name} #{join_clause} WHERE #{conditions_clause}"
  end
      
  def order_clause
    return unless @sort_order
    # prevent sql-injection attacks from the list view page which takes order by and passes it here
    "ORDER BY #{@sort_order.gsub(/[^\w_, \.\(\)]/, '')}"
  end

  def conditions_clause(conditions = @conditions)
    return "(#{conditions})" if conditions.kind_of?(String)
    raise 'refusing to fetch ids without conditions' if conditions.nil?
    operator = conditions.first
    raise "invalid operator :#{operator} in conditions" unless valid_operator?(operator)
    condition_strings = conditions.slice(1, conditions.size - 1).collect do |condition|
      "#{conditions_clause(condition)}"
    end.sort_by {|s| s.size}

    case condition_strings.size
    when 0
      raise "empty conditions found in: #{@conditions.inspect}"
    when 1
      if operator == :not
        "NOT #{condition_strings.first}"
      else
        condition_strings.first
      end
    else
      case operator
      when :and
        "(#{condition_strings.join(' AND ')})"
      when :or
        "(#{condition_strings.join(' OR ')})"
      else
        raise 'operator :not is unary; multiple sub-conditions provided'
      end
    end
  end

  def join_clause
    return unless @joins or @sort_joins
    joins = []
    joins << @joins      if @joins
    joins << @sort_joins if @sort_joins
    joins.join(' ')
  end

  def as_id(model)
    case model
    when model_class
      # Save the model object if it is of the same type as our models.
      id = model.send(id_field)
      models_by_id[id] ||= model
    when ActiveRecord::Base
      id = model.id
    else
      id = model.to_i
    end
    raise "id not found for model: #{model.inspect}" if id.nil?
    id
  end

  def as_ids(models)
    return [] unless models
    case models
    when ModelSet
      models.ids
    when MultiSet
      models.ids_by_class[model_class]
    else
      models = [models] if not models.kind_of?(Enumerable)
      models.collect {|model| as_id(model) }
    end
  end

  def valid_operator?(operator)
    [:and, :or, :not].include?(operator)
  end
end

class ActiveRecord::Base
  def self.has_set(name, options = {}, &extension)
    namespace = self.name.split('::')
    if namespace.empty?
      namespace = ''
    else
      namespace[-1] = ''
      namespace = namespace.join('::')
    end

    if options[:set_class]
      options[:set_class] = namespace + options[:set_class]
      other_class         = options[:set_class].constantize.model_class
    else
      options[:class_name] ||= name.to_s.singularize.camelize
      options[:class_name] = namespace + options[:class_name].to_s
      options[:set_class]  = options[:class_name] + 'Set'
      other_class          = options[:class_name].constantize
    end

    set_class = begin
      options[:set_class].constantize
    rescue NameError
      module_eval "class ::#{options[:set_class]} < ModelSet; end"
      options[:set_class].constantize
    end

    extension_module = if extension
      Module.new(&extension)
    end

    initial_set_all = if options[:filters] and options[:filters].first == :all
      options[:filters].shift
      true
    end

    define_method name do |*args|
      @model_set_cache ||= {}
      @model_set_cache[name] = nil if args.first == true # Reload the set.
      if @model_set_cache[name].nil?

        if initial_set_all
          set = set_class.all
        else
          own_key = options[:own_key] || self.class.table_name.singularize + '_id'
          if options[:as]
            as_clause = "AND #{options[:as]}_type = '#{self.class}'"
            own_key = "#{options[:as]}_id" unless options[:own_key]
          end
          if options[:through]
            other_key = options[:other_key] || other_class.table_name.singularize + '_id'
            where_clause = "#{own_key} = #{id}"
            where_clause << " AND #{options[:through_conditions]}" if options[:through_conditions]
            set = set_class.find_by_sql %{
              SELECT #{other_key} FROM #{options[:through]}
               WHERE #{where_clause} #{as_clause}
            }
          else
            set = set_class.find_by_sql %{
              SELECT #{set_class.id_field} FROM #{set_class.table_name}
               WHERE #{own_key} = #{id} #{as_clause}
            }
          end
        end
        
        set.instance_variable_set(:@parent_model, self)
        def set.parent_model
          @parent_model
        end

        if options[:filters]
          options[:filters].each do |filter_name|
            filter_name = "#{filter_name}!"
            if set.method(filter_name).arity == 0
              set.send(filter_name)
            else
              set.send(filter_name, self)
            end
          end
        end

        set.add_joins!(options[:joins]) if options[:joins]
        set.add_conditions!(options[:conditions]) if options[:conditions]
        set.order_by!(options[:order]) if options[:order]
        set.extend(extension_module) if extension_module
        @model_set_cache[name] = set
      end
      if options[:clone] == false or args.include?(:no_clone)
        @model_set_cache[name] 
      else
        @model_set_cache[name].clone
      end
    end
    
    define_method :reset_model_set_cache do
      @model_set_cache = {}
    end
  end
end

require 'rubygems'
require 'active_record'
require 'deep_clonable'
require 'ordered_set'

$:.unshift(File.dirname(__FILE__))
require 'multi_set'
require 'model_set/query'
require 'model_set/set_query'
require 'model_set/conditions'
require 'model_set/conditioned'
require 'model_set/sql_base_query'
require 'model_set/sql_query'
require 'model_set/raw_sql_query'
require 'model_set/solr_query'
require 'model_set/sphinx_query'

class ModelSet
  include Enumerable
  include ActiveSupport::CoreExtensions::Array::Conversions

  deep_clonable

  MAX_CACHE_SIZE = 1000 if not defined?(MAX_CACHE_SIZE)

  def initialize(query_or_models)
    if query_or_models.kind_of?(Query)
      @query = query_or_models
    elsif query_or_models.kind_of?(self.class)
      self.ids = query_or_models.ids
      @models_by_id = query_or_models.models_by_id
    elsif query_or_models
      self.ids = as_ids(query_or_models)
    end
  end

  def ids
    model_ids.to_a
  end

  def missing_ids
    ( @missing_ids || [] ).uniq
  end

  [:add!, :unshift!, :subtract!, :intersect!, :reorder!].each do |action|  
    define_method(action) do |models|
      anchor!(:set)
      query.send(action, as_ids(models))
      self
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
    query.count
  end

  def size
    query.size
  end
  alias length size

  def any?
    return super if block_given?
    return true  if query.nil?
    size > 0
  end

  def empty?
    not any?
  end

  def empty!
    self.ids = []
    self
  end

  def ids=(model_ids)
    model_ids = model_ids.collect {|id| id.to_i}
    self.query = SetQuery.new(self.class)
    query.add!(model_ids)
    self
  end

  def query=(query)
    @query = query
  end

  QUERY_TYPES = {
    :set    => SetQuery,
    :sql    => SQLQuery,
    :solr   => SolrQuery,
    :sphinx => SphinxQuery,
  } if not defined?(QUERY_TYPES)

  attr_reader :query

  def query_class(type = query.class)
    type.kind_of?(Symbol) ? QUERY_TYPES[type] : type
  end

  def query_type?(type)
    query_class(type) == query_class
  end

  def anchor!(type = default_query_type)
    return unless type
    query_class = query_class(type)
    if not query_type?(query_class)
      self.query = query_class.new(self)
    end
    self
  end
  
  def limit?
    not @limit.nil?
  end

  def default_query_type
    :sql
  end

  [:add_conditions!, :add_joins!, :in!, :invert!, :order_by!].each do |method_name|
    clone_method method_name
    define_method(method_name) do |*args|
      # Use the default query engine if none is specified.
      anchor!( extract_opt(:query_type, args) || default_query_type )

      query.send(method_name, *args)
      self
    end
  end

  [:unsorted!, :limit!, :page!, :unlimited!].each do |method_name|
    clone_method method_name
    define_method(method_name) do |*args|
      # Don't change the query engine by default
      anchor!( extract_opt(:query_type, args) )

      query.send(method_name, *args)
      self
    end
  end

  def extract_opt(key, args)
    opts = args.last.kind_of?(Hash) ? args.pop : {}
    opt  = opts.delete(key)
    args << opts unless opts.empty?
    opt
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

  def aggregate(*args)
    anchor!(:sql)
    query.aggregate(*args)
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
    @query             = @query.clone             if @query
    @model_ids         = @model_ids.clone         if @model_ids
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
    query = RawSQLQuery.new
    query.sql = sql
    new(query)
  end

  def self.constructor(filter_name, opts = nil)
    (class << self; self; end).module_eval do
      define_method filter_name do |*args|
        if opts
          args.last.kind_of?(Hash) ? args.last.reverse_merge!(opts.clone) : args << opts.clone
        end
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

  def self.model_name
    model_class.name
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

  def self.id_field(id_field = nil)
    if id_field.nil?
      @id_field ||= 'id'
    else
      @id_field = id_field
    end
  end

  def self.id_field_with_prefix
    "#{self.table_name}.#{self.id_field}"
  end

  # Define instance methods based on class methods.
  [:model_class, :model_name, :table_name, :id_field, :id_field_with_prefix].each do |method|
    define_method(method) do |*args|
      self.class.send(method, *args)
    end
  end

protected

  def db
    model_class.connection
  end

  def models_by_id
    @models_by_id ||= {}
  end

  def model_ids
    query.ids
  end
  
private

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
          :conditions => db.ids_clause(ids_to_fetch, id_field_with_prefix),
          :include    => @included_models
        )
      end
      models.each do |model|
        id = model.send(id_field)
        models_by_id[id] ||= model
      end
    end
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
      merge_cache!(models)
      models.ids
    when MultiSet
      models.ids_by_class[model_class]
    else
      models = [models] if not models.kind_of?(Enumerable)
      models.collect {|model| as_id(model) }
    end
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

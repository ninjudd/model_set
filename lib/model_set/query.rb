class ModelSet
  class Query
    deep_clonable

    def initialize(model_set = ModelSet)
      if model_set.kind_of?(Class)
        @set_class = model_set
      else
        @set_class = model_set.class
        anchor!(model_set.query) if model_set.query
      end
    end
    
    attr_reader :set_class
    delegate :id_field, :table_name, :id_field_with_prefix, :model_class, :to => :set_class

  private

    def limit_and_offset(opts)
      if opts[:limit]
        opts[:offset] ||= opts[:page] ? (opts[:page] - 1) * opts[:limit] : 0
      end
      [ opts[:limit], opts[:offset] ]
    end

    def limit_and_page(opts)
      if opts[:limit]
        opts[:page] ||= opts[:offset] ? (opts[:offset] / opts[:limit]) : 1
      end
      [ opts[:limit], opts[:page] ]
    end
  end
end

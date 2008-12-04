class ModelSet
  class SQLQuery < ConditionsQuery
    include SQLMethods 

    def anchor!(query, opts = {})
      if query.respond_to?(:sql)
        sql = "#{id_field_with_prefix} IN (#{ query.sql(opts) })"
      else
        sql = ids_clause( query.ids(opts) )
      end
      add_conditions!(sql)
    end
    
    def aggregate(query, opts = {})
      sql = "SELECT #{query} #{from_clause}"
      sql << " LIMIT #{opts[:limit]}"       if opts[:limit]
      sql << " GROUP BY #{opts[:group_by]}" if opts[:group_by]
      result = db.select_rows(sql).first
      result.size == 1 ? result.first : result
    end

    def add_joins!(*joins)
      @joins ||= []

      joins.each do |join|
        @joins << sanitize(join)
      end
      @joins.uniq!
      self
    end

    def in!(ids, field = id_field_with_prefix)
      add_conditions!( ids_clause(ids, field) )
    end

    def order_by!(order, joins = nil)
      @sort_order = order
      @sort_joins = joins
      self
    end
  
    def sql(opts = {})
      "#{select_clause} #{from_clause} #{order_clause} #{limit_clause(opts)}"
    end

    def count
      aggregate("COUNT(DISTINCT #{id_field_with_prefix})").to_i
    end
    
  private
    
    def select_clause
      "SELECT #{id_field_with_prefix}"
    end
        
    def from_clause
      "FROM #{table_name} #{join_clause} WHERE #{conditions_clause}"
    end
    
    def order_clause
      return unless @sort_order
      # Prevent SQL injection attacks.
      "ORDER BY #{@sort_order.gsub(/[^\w_, \.\(\)]/, '')}"
    end
    
    def conditions_clause
      conditions.to_s
    end
    
    def join_clause
      return unless @joins or @sort_joins
      joins = []
      joins << @joins      if @joins
      joins << @sort_joins if @sort_joins      
      joins.join(' ')
    end
  end
end

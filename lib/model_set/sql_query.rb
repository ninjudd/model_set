class ModelSet
  class SQLQuery < SQLBaseQuery
    include Conditioned

    def anchor!(query)
      if query.respond_to?(:sql)
        sql = "#{id_field_with_prefix} IN (#{query.sql})"
      else
        sql = ids_clause(query.ids)
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
        @joins << sanitize_condition(join)
      end
      @joins.uniq!

      clear_cache!
    end

    def in!(ids, field = id_field_with_prefix)
      add_conditions!( ids_clause(ids, field) )
    end

    def order_by!(order, joins = nil)
      @sort_order = order
      @sort_joins = joins
      clear_cache!
    end
  
    def sql
      "#{select_clause} #{from_clause} #{order_clause} #{limit_clause}"
    end

    def count
      @count ||= limit ? aggregate("COUNT(DISTINCT #{id_field_with_prefix})").to_i : size
    end
    
  private
    
    def select_clause
      "SELECT #{id_field_with_prefix}"
    end
        
    def from_clause
      "FROM #{table_name} #{join_clause} WHERE #{conditions.to_s}"
    end
    
    def order_clause
      return unless @sort_order
      # Prevent SQL injection attacks.
      "ORDER BY #{@sort_order.gsub(/[^\w_, \.\(\)'\"]/, '')}"
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

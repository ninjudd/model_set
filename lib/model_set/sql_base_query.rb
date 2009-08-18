class ModelSet
  class SQLBaseQuery < Query
    # SQL methods common to SQLQuery and RawSQLQuery.
    def ids
      @ids ||= fetch_id_set(sql)
    end
    
    def size
      @size ||= ids.size
    end

  private
    
    def ids_clause(ids, field = id_field_with_prefix)
      db.ids_clause(ids, field)
    end

    def fetch_id_set(sql)
      db.select_values(sql).collect {|id| id.to_i}.to_ordered_set
    end

    def db
      model_class.connection
    end
    
    def sanitize_condition(condition)
      model_class.send(:sanitize_sql, condition)
    end
    
    def limit_clause
      return unless limit
      limit_clause = "LIMIT #{limit}"
      limit_clause << " OFFSET #{offset}" if offset > 0
      limit_clause
    end
  end
end

class ActiveRecord::ConnectionAdapters::AbstractAdapter
  def ids_clause(ids, field)
    # Make sure all ids are integers to prevent SQL injection attacks.
    ids = ids.collect {|id| id.to_i}

    if ids.empty?
      "FALSE"
    elsif kind_of?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
      "#{field} = ANY ('{#{ids.join(',')}}'::bigint[])"
    else
      "#{field} IN (#{ids.join(',')})"
    end
  end
end

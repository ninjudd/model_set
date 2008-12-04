class ModelSet
  module SQLMethods    
    def postgres?
      defined?(PGconn) and db.raw_connection.is_a?(PGconn)
    end
    
    def ids_clause(ids, field = id_field_with_prefix)
      db.ids_clause(ids, field)
    end

    def ids(opts = {})
      db.select_values( sql(opts) ).collect {|id| id.to_i}
    end
    
  protected
    
    def db
      model_class.connection
    end

  private
    
    def sanitize(condition)
      ActiveRecord::Base.send(:sanitize_sql, condition)
    end
    
    def limit_clause(opts)
      limit, offset = limit_and_offset(opts)
      return unless limit
      limit_clause = "LIMIT #{limit.to_i}"
      limit_clause << " OFFSET #{offset.to_i}" if offset > 0
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

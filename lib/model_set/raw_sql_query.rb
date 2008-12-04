class ModelSet
  class RawSQLQuery < Query
    include SQLMethods

    def sql=(sql)
      ['LIMIT', 'OFFSET'].each do |term|
        raise "#{term} not permitted in raw sql" if sql.match(/ #{term} \d+/i)
      end
      @sql = sql
    end
    
    def sql(opts = {})
      "#{@sql} #{limit_clause(opts)}"
    end
  end
end

class ModelSet
  class RawSQLQuery < SQLBaseQuery
    def sql=(sql)
      ['LIMIT', 'OFFSET'].each do |term|
        raise "#{term} not permitted in raw sql" if sql.match(/ #{term} \d+/i)
      end
      @sql = sql
    end
    
    def sql
      "#{@sql} #{limit_clause}"
    end

    def count
      # The only way to get the count if there is a limit is to fetch all ids without the limit.
      @count ||= limit ? fetch_id_set(@sql).size : size
    end
  end
end

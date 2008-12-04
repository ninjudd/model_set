class ModelSet
  class ConditionsQuery < Query
    attr_reader :conditions, :sort_order
    
    def add_conditions!(*conditions)
      operator = conditions.shift if conditions.first.kind_of?(Symbol)
      operator ||= :and

      # Sanitize conditions.
      conditions.collect! do |condition|
        condition.kind_of?(Conditions) ? condition : Conditions.new(sanitize(condition))
      end

      if operator == :not
        # In this case, :not actually means :and :not.
        conditions = ~Conditions.new(:and, *conditions)
        operator   = :and
      end

      conditions << @conditions if @conditions
      @conditions = Conditions.new(operator, *conditions)
      self
    end

    def invert!
      raise 'cannot invert without conditions' if @conditions.nil?
      @conditions = ~@conditions
      self
    end

    def order_by!(order)
      @sort_order = order
      self
    end

    def unsorted!
      @sort_order = nil
      self
    end
    
  private

    def sanitize(clause)
      clause
    end
  end
end

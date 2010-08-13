class ModelSet
  module Conditioned
    # Shared methods for dealing with conditions.
    attr_accessor :conditions
    
    def add_conditions!(*conditions)
      operator = conditions.shift if conditions.first.kind_of?(Symbol)
      operator ||= :and

      # Sanitize conditions.
      conditions.collect! do |condition|
        condition.kind_of?(Conditions) ? condition : Conditions.new( sanitize_condition(condition) )
      end

      if operator == :not
        # In this case, :not actually means :and :not.
        conditions = ~Conditions.new(:and, *conditions)
        operator   = :and
      end

      conditions << @conditions if @conditions
      @conditions = Conditions.new(operator, *conditions)

      clear_cache!
    end

    def invert!
      raise 'cannot invert without conditions' if @conditions.nil?
      @conditions = ~@conditions
      clear_cache!
    end
  end
end

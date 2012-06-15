class ModelSet
  module Conditioned
    # Shared methods for dealing with conditions.
    attr_accessor :conditions

    def add_conditions!(*conditions)
      new_conditions = conditions.first.kind_of?(Symbol) ? [conditions.shift] : []

      conditions.each do |condition|
        if condition.kind_of?(Conditions)
          new_conditions << condition
        else
          new_conditions.concat([*transform_condition(condition)])
        end
      end
      return self if new_conditions.empty?

      @conditions = to_conditions(*new_conditions) << @conditions
      clear_cache!
    end

    def to_conditions(*conditions)
      Conditions.new(conditions, condition_ops)
    end

    def invert!
      raise 'cannot invert without conditions' if @conditions.nil?
      @conditions = ~@conditions
      clear_cache!
    end
  end
end

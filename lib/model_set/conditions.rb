class ModelSet
  class Conditions
    deep_clonable

    attr_reader :operator, :conditions

    def new(*args)
      self.class.new(*args)
    end

    def initialize(conditions, ops)
      if conditions.kind_of?(Array)
        @ops      = ops
        @operator = conditions.first.kind_of?(Symbol) ? conditions.shift : :and
        if @operator == :not
          # In this case, :not actually means :and :not.
          @conditions = ~Conditions.new([:and, conditions], @ops)
        else
          raise "invalid operator :#{operator}" unless [:and, :or].include?(@operator)
          # Compact the conditions if possible.
          @conditions = []
          conditions.each do |clause|
            self << clause
          end
        end
      else
        @conditions = [conditions]
      end
    end

    def terminal?
      operator.nil?
    end

    def <<(clause)
      return self unless clause
      raise 'cannot append conditions to a terminal' if terminal?

      clause = new(clause, @ops) unless clause.kind_of?(Conditions)
      if clause.operator == operator
        @conditions.concat(clause.conditions)
      else
        @conditions << clause
      end
      @conditions.uniq!
      self
    end

    def ~
      if operator == :not
        conditions.first.clone
      else
        new(:not, self)
      end
    end

    def |(other)
      new(:or, self, other)
    end

    def &(other)
      new(:and, self, other)
    end

    def op(type)
      @ops[type]
    end

    def to_s
      return conditions.first.to_s if terminal? or conditions.empty?

      condition_strings = conditions.collect {|c| c.to_s}.sort_by {|s| s.size}

      case operator
      when :not then
        "(#{op(:not)} #{condition_strings.first})"
      when :and then
        "(#{condition_strings.join(op(:and))})"
      when :or then
        "(#{condition_strings.join(op(:or))})"
      end
    end

    def hash
      # for uniq
      [operator, conditions].hash
    end

    def eql?(other)
      # for uniq
      self.hash == other.hash
    end
  end
end

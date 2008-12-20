class ModelSet
  class Conditions
    deep_clonable

    attr_reader :operator, :conditions

    def self.new(*args)
      if args.size == 1 and args.first.kind_of?(self)
        # Just clone if the only argument is a Conditions object.
        args.first.clone
      elsif args.size == 2 and [:and, :or].include?(args.first)
        # The operator is not necessary if there is only one subcondition.
        new(args.last)
      else
        super
      end
    end

    def new(*args)
      self.class.new(*args)
    end

    def initialize(*args)
      if args.size == 1 and not args.first.kind_of?(Symbol)
        # Terminal.
        @conditions = args
      else
        @operator = args.shift
        raise "invalid operator :#{operator}" unless [:and, :or, :not].include?(operator)

        if operator == :not
          raise "unary operator :not cannot have multiple conditions" if args.size > 1
          @conditions = [self.class.new(args.first)] 
        else
          # Compact the conditions if possible.
          @conditions = []
          args.each do |clause|
            self << clause
          end
        end
      end
    end

    def terminal?
      operator.nil?
    end

    def <<(clause)
      raise 'cannot append conditions to a terminal' if terminal?
      
      clause = self.class.new(clause) 
      if clause.operator == operator
        @conditions.concat(clause.conditions)
      else
        @conditions << clause
      end
      @conditions.uniq!
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

    def to_s
      return conditions.first if terminal?

      condition_strings = conditions.collect do |condition|
        condition.operator == :not ? condition.to_s : "(#{condition.to_s})"
      end.sort_by {|s| s.size}

      case operator
      when :not
        "NOT #{condition_strings.first}"
      when :and
        "#{condition_strings.join(' AND ')}"
      when :or
        "#{condition_strings.join(' OR ')}"
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

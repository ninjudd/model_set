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
      if args.size == 1
        # Terminal.
        @conditions = args
      else
        @operator = args.shift
        raise "invalid operator :#{operator}" unless [:and, :or, :not].include?(operator)
        raise "empty conditions not permitted" if args.empty?

        if operator == :not
          raise "unary operator :not cannot have multiple conditions" if arg.size > 1
          @conditions = [self.class.new(args.first)] 
        else
          # Compact the conditions if possible.
          @conditions = []
          args.each do |clause|
            clause = self.class.new(clause) 
            if clause.operator == operator
              @conditions.concat(clause.conditions)
            else
              @conditions << clause
            end
          end
          @conditions.uniq!
         end
      end
    end

    def terminal?
      @operator.nil?
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
        "(#{condition.to_s})"
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

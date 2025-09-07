# frozen_string_literal: true

module Kumi
  module Core
    module NAST
      @next_id_mutex = Mutex.new
      @next_id = 1
      
      def self.next_id
        @next_id_mutex.synchronize { @next_id += 1 }
      end
      
      def self.reset_id_counter!
        @next_id_mutex.synchronize { @next_id = 1 }
      end
      
      Node = Struct.new(:id, :loc, :meta, keyword_init: true) do
        def initialize(**args)
          super
          self.id ||= NAST.next_id
          self.meta ||= {}
        end

        def accept(visitor)
          visitor.visit_node(self)
        end
      end

      class Const < Node
        attr_reader :value
        def initialize(value:, **k)
          super(**k)
          @value = value
        end

        def accept(visitor)
          visitor.visit_const(self)
        end
      end

      class InputRef < Node
        attr_reader :path
        def initialize(path:, **k)
          super(**k)
          @path = Array(path).map(&:to_sym)
        end

        def path_fqn
          @path.join('.')
        end

        def accept(visitor)
          visitor.visit_input_ref(self)
        end
      end

      class Ref < Node
        attr_reader :name
        def initialize(name:, **k)
          super(**k)
          @name = name.to_sym
        end

        def accept(visitor)
          visitor.visit_ref(self)
        end
      end

      class Call < Node
        attr_reader :fn, :args
        def initialize(fn:, args:, **k)
          super(**k)
          @fn = fn.to_sym
          @args = args
        end

        def accept(visitor)
          visitor.visit_call(self)
        end
      end

      class Tuple < Node
        attr_reader :args
        def initialize(args:, **k)
          super(**k)
          @args = args
        end

        def accept(visitor)
          visitor.visit_tuple(self)
        end
      end

      class Field < Node
        attr_reader :key, :value
        def initialize(key:, value:, **k)
          super(**k)
          @key = key.to_sym
          @value = value
        end

        def accept(visitor)
          visitor.visit_field(self)
        end
      end

      class Hash < Node
        attr_reader :fields
        def initialize(fields:, **k)
          super(**k)
          @fields = fields
        end

        def accept(visitor)
          visitor.visit_hash(self)
        end
      end

      # Control: ternary select (pure, eager)
      class Select < Node
        attr_reader :cond, :on_true, :on_false
        def initialize(cond:, on_true:, on_false:, **k)
          super(**k)
          @cond, @on_true, @on_false = cond, on_true, on_false
        end

        def accept(visitor)
          visitor.respond_to?(:visit_select) ? visitor.visit_select(self) : super
        end
      end

      # Semantic reduction over explicit axes, with kernel id (e.g., :"agg.sum")
      class Reduce < Node
        attr_reader :op_id, :over, :arg
        def initialize(op_id:, over:, arg:, **k)
          super(**k)
          @op_id = op_id.to_sym
          @over  = Array(over).map!(&:to_sym)
          @arg   = arg
        end

        def accept(visitor)
          visitor.respond_to?(:visit_reduce) ? visitor.visit_reduce(self) : super
        end
      end


      class Declaration < Node
        attr_reader :name, :body
        def initialize(name:, body:, **k)
          super(**k)
          @name = name.to_sym
          @body = body
        end

        def accept(visitor)
          visitor.visit_declaration(self)
        end

        def kind
          meta[:kind]
        end
      end

      Module = Struct.new(:decls, keyword_init: true) do
        def accept(visitor)
          visitor.visit_module(self)
        end
      end
    end
  end
end

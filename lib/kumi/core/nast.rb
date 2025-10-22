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
        attr_reader :path, :fqn, :key_chain, :element_terminal

        def initialize(path:, fqn: nil, key_chain: [], element_terminal: false, **k)
          super(**k)
          @path = Array(path).map!(&:to_sym)
          @fqn  = fqn || @path.join(".")
          @key_chain = Array(key_chain).map!(&:to_sym)
          @element_terminal = !!element_terminal
        end

        def path_fqn = @fqn

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

      class IndexRef < Node
        attr_reader :name, :input_fqn, :axes

        def initialize(name:, input_fqn:, **k)
          super(**k)
          @name = name.to_sym
          @input_fqn = input_fqn
        end

        def axes
          meta[:stamp][:axes]
        end

        def accept(visitor) = visitor.respond_to?(:visit_index_ref) ? visitor.visit_index_ref(self) : super
      end

      class Call < Node
        attr_reader :fn, :args, :opts

        def initialize(fn:, args:, opts: {}, **k)
          super(**k)
          @fn = fn.to_sym
          @args = args
          @opts = opts
        end

        def accept(visitor)
          visitor.visit_call(self)
        end
      end

      class ImportCall < Node
        attr_reader :fn_name, :args, :input_mapping_keys, :source_module

        def initialize(fn_name:, args:, input_mapping_keys:, source_module:, **k)
          super(**k)
          @fn_name = fn_name.to_sym
          @args = args
          @input_mapping_keys = input_mapping_keys
          @source_module = source_module
        end

        def accept(visitor)
          visitor.respond_to?(:visit_import_call) ? visitor.visit_import_call(self) : super
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

      class Pair < Node
        attr_reader :key, :value

        def initialize(key:, value:, **k)
          super(**k)
          @key = key
          @value = value
        end

        def accept(visitor)
          visitor.visit_pair(self)
        end
      end

      class Hash < Node
        attr_reader :pairs

        def initialize(pairs:, **k)
          super(**k)
          @pairs = pairs
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
          @cond = cond
          @on_true = on_true
          @on_false = on_false
        end

        def accept(visitor)
          visitor.respond_to?(:visit_select) ? visitor.visit_select(self) : super
        end
      end

      # Semantic reduction over explicit axes, with kernel id (e.g., :"agg.sum")
      class Fold < Node
        attr_reader :fn, :arg

        def initialize(fn:, arg:, **k)
          super(**k)
          @fn = fn.to_sym
          @arg = arg
        end

        def accept(visitor)
          visitor.respond_to?(:visit_fold) ? visitor.visit_fold(self) : super
        end
      end

      # Semantic reduction over explicit axes, with kernel id (e.g., :"agg.sum")
      class Reduce < Node
        attr_reader :fn, :over, :arg

        def initialize(fn:, over:, arg:, **k)
          super(**k)
          @fn = fn.to_sym
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

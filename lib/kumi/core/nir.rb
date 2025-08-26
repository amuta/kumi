# frozen_string_literal: true

module Kumi
  module Core
    module NIR
      Node = Struct.new(:loc, keyword_init: true)

      class Const < Node
        attr_reader :value
        def initialize(value:, **k)
          super(**k)
          @value = value
        end
      end

      class InputRef < Node
        attr_reader :path
        def initialize(path:, **k)
          super(**k)
          @path = Array(path).map(&:to_sym)
        end
      end

      class Ref < Node
        attr_reader :name
        def initialize(name:, **k)
          super(**k)
          @name = name.to_sym
        end
      end

      class Call < Node
        attr_reader :fn, :args
        def initialize(fn:, args:, **k)
          super(**k)
          @fn = fn.to_sym
          @args = args
        end
      end

      Decl = Struct.new(:name, :kind, :body, :loc, keyword_init: true)
      Module = Struct.new(:decls, keyword_init: true)
    end
  end
end
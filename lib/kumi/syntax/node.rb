# frozen_string_literal: true

module Kumi
  module Syntax
    # A struct to hold standardized source location information.

    # Base module included by all AST nodes to provide a standard
    # interface for accessing source location information..
    module Node
      attr_accessor :loc, :hints

      def initialize(*args, hints: {}, loc: nil, **kwargs)
        @loc = loc
        @hints = hints

        super(*args, **kwargs)
        freeze
      end

      def ==(other)
        other.is_a?(self.class) &&
          # for Struct-based nodes
          (if respond_to?(:members)
             members.all? { |m| self[m] == other[m] }
           else
             instance_variables.reject { |iv| iv == :@loc }
                                        .all? do |iv|
               instance_variable_get(iv) ==
                                            other.instance_variable_get(iv)
             end
           end
          )
      end
      alias eql? ==
    end
  end
end

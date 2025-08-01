# frozen_string_literal: true

module Kumi
  module Syntax
      # A struct to hold standardized source location information.
      Location = Struct.new(:file, :line, :column, keyword_init: true)

      # Base module included by all AST nodes to provide a standard
      # interface for accessing source location information..
      module Node
        attr_accessor :loc

        def initialize(*args, loc: nil, **kwargs)
          @loc = loc
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

        def hash
          values = if respond_to?(:members)
                     members.map { |m| self[m] }
                   else
                     instance_variables.reject { |iv| iv == :@loc }
                                       .map { |iv| instance_variable_get(iv) }
                   end
          [self.class, *values].hash
        end
      end
  end
end

# frozen_string_literal: true

module Kumi
  module Core
    module Functions
      # Minimal function specification for NAST dimensional analysis
      FunctionSpec = Struct.new(
        :id,                       # "core.add"
        :kind,                     # :elementwise, :reduce, :constructor
        :parameter_names,          # [:left_operand, :right_operand]
        :dtype_rule,               # "promote(left_operand,right_operand)" or proc
        :constraint_semantics,     # formal constraint metadata (hash or nil)
        keyword_init: true
      )
    end
  end
end

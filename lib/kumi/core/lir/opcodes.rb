# lib/kumi/core/lir/opcodes.rb
# Defines the canonical opcode set for LIR.
module Kumi
  module Core
    module LIR
      OPCODES = %i[
        Constant
        LoadInput
        LoadDeclaration
        LoadField
        LoopStart
        LoopEnd
        KernelCall
        Select
        DeclareAccumulator
        Accumulate
        LoadAccumulator
        Yield
      ].freeze
    end
  end
end
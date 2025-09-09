# lib/kumi/core/lir.rb
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
        MakeTuple
        MakeObject
        TupleGet
        Yield
      ].freeze

      # Re-exports for stable API
      Stamp       = Structs::Stamp
      Literal     = Structs::Literal
      Instruction = Structs::Instruction

      # Re-export support classes
      Ids   = Support::Ids
      Error = Support::Error
    end
  end
end

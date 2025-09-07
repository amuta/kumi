# lib/kumi/core/lir.rb
module Kumi
  module Core
    module LIR
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
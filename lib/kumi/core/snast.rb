# frozen_string_literal: true
module Kumi
    module Core
      module SNAST
        NAST = Kumi::Core::NAST
  
        # Reuse NAST nodes verbatim
        Node        = NAST::Node
        Const       = NAST::Const
        InputRef    = NAST::InputRef
        Ref         = NAST::Ref
        Call        = NAST::Call
        Tuple       = NAST::Tuple
        Field       = NAST::Field
        Hash        = NAST::Hash
        Declaration = NAST::Declaration9
        Module      = NAST::Module
      end
    end
  end
  
# frozen_string_literal: true

module Kumi
  module Codegen
    module V2
      module StreamIR
        Function = Struct.new(:name, :rank, :ops, keyword_init: true)

        module Op
          def self.open_loop(depth:, base_chain:, key:) = {k: :OpenLoop, depth:, base_chain:, key:}
          def self.init_index(depth:)                   = {k: :InitIndex, depth:}
          def self.load_iter(depth:)                    = {k: :LoadIter, depth:}        # a{depth} = arr{depth}[i{depth}]
          def self.next_array(depth:, key:)             = {k: :NextArray, depth:, key:} # arr{depth+1} = a{depth}[key]
          def self.acc_reset(name:, depth:)             = {k: :AccReset, name:, depth:}
          def self.acc_add(name:, expr:)                = {k: :AccAdd, name:, expr:}
          def self.emit(code:)                          = {k: :Emit, code:}
          def self.yield(expr:, indices:)               = {k: :Yield, expr:, indices:}
          def self.close_loop(depth:)                   = {k: :CloseLoop, depth:}
        end
      end
    end
  end
end
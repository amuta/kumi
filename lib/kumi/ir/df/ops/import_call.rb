# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Ops
        class ImportCall < Node
          opcode :import_call

          def initialize(fn_name:, source_module:, args:, mapping_keys:, **kwargs)
            super(
              inputs: Array(args),
              attributes: {
                fn_name: fn_name.to_sym,
                source_module: source_module.to_s,
                mapping_keys: Array(mapping_keys).map(&:to_sym)
              },
              **kwargs
            )
          end
        end
      end
    end
  end
end

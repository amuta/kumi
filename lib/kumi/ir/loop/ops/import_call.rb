# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Ops
        class ImportCall < Node
          opcode :import_call

          def initialize(result:, fn_name:, source_module:, args:, axes:, dtype:, metadata: {})
            attrs = {
              fn_name: fn_name.to_sym,
              source_module: source_module.to_s
            }
            super(result:, axes:, dtype:, inputs: Array(args), attributes: attrs, metadata: metadata)
          end
        end
      end
    end
  end
end

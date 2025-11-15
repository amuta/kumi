# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Ops
        class ImportCall < Node
          opcode :import_call

          def initialize(result:, fn_name:, source_module:, args:, mapping_keys:, axes:, dtype:, metadata: {})
            attrs = {
              fn_name: fn_name.to_sym,
              source_module: source_module.to_s,
              mapping_keys: Array(mapping_keys).map(&:to_sym)
            }
            super(result:, axes:, dtype:, inputs: Array(args), attributes: attrs, metadata:)
          end

          def mapping_keys = attributes[:mapping_keys]
        end
      end
    end
  end
end

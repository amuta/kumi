# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      module Accessors
        class EachAccessor
          extend Base

          def self.build(operations, path_key, policy, key_policy)
            # Reuse EachIndexed walker, ignore indices
            walker = EachIndexedAccessor.build_each_walker(operations, path_key, policy, key_policy)
            lambda do |data, &blk|
              if blk
                walker.call(data, 0, [], ->(val, _idx) { blk.call(val) })
                nil
              else
                out = []
                walker.call(data, 0, [], ->(val, _idx) { out << val })
                out
              end
            end
          end
        end
      end
    end
  end
end

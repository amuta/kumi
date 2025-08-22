# frozen_string_literal: true
module Kumi::Core::Compiler::AccessEmit
  module Materialize
    extend Base
    module_function
    def build(plan)
      policy     = plan.on_missing || :error
      key_policy = plan.key_policy || :indifferent
      path_key   = plan.path
      segs       = segment_ops(plan.operations)

      code = +"lambda do |data|\n"
      nodev, depth, map_depth = "node0", 0, 0
      code << "  #{nodev} = data\n"

      segs.each do |seg|
        if seg == :array
          code << "  #{array_guard_code(node_var: nodev, mode: :materialize, policy: policy, path_key: path_key, map_depth: map_depth)}\n"
          child = "node#{depth + 1}"
          code << "  #{nodev} = #{nodev}.map do |__e#{depth}|\n"
          code << "    #{child} = __e#{depth}\n"
          nodev = child; depth += 1; map_depth += 1
        else
          seg.each do |(_, key, preview)|
            code << "  "
            code << fetch_hash_code(node_var: nodev, key: key, key_policy: key_policy,
                                    preview_array: preview, mode: :materialize, policy: policy,
                                    path_key: path_key, map_depth: map_depth)
            code << "\n"
          end
        end
      end

      while map_depth.positive?
        code << "  " * map_depth + "#{nodev}\n"
        code << "  " * (map_depth - 1) + "end\n"
        nodev = "node#{depth - 1}"
        depth -= 1
        map_depth -= 1
      end
      code << "  #{nodev}\nend\n"
      code
    end
  end
end
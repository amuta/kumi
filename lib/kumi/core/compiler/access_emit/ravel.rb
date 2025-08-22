# frozen_string_literal: true
module Kumi::Core::Compiler::AccessEmit
  module Ravel
    extend Base
    module_function
    def build(plan)
      policy     = plan.on_missing || :error
      key_policy = plan.key_policy || :indifferent
      path_key   = plan.path
      segs       = segment_ops(plan.operations)

      code = +"lambda do |data|\n"
      code << "  out = []\n"
      nodev, depth, loop_depth = "node0", 0, 0
      code << "  #{nodev} = data\n"

      segs.each do |seg|
        if seg == :array
          code << "  #{array_guard_code(node_var: nodev, mode: :ravel, policy: policy, path_key: path_key, map_depth: loop_depth)}\n"
          code << "  ary#{loop_depth} = #{nodev}\n"
          code << "  len#{loop_depth} = ary#{loop_depth}.length\n"
          code << "  i#{loop_depth} = -1\n"
          code << "  while (i#{loop_depth} += 1) < len#{loop_depth}\n"
          child = "node#{depth + 1}"
          code << "    #{child} = ary#{loop_depth}[i#{loop_depth}]\n"
          nodev = child; depth += 1; loop_depth += 1
        else
          seg.each do |(_, key, preview)|
            code << "  "
            code << fetch_hash_code(node_var: nodev, key: key, key_policy: key_policy,
                                    preview_array: preview, mode: :ravel, policy: policy,
                                    path_key: path_key, map_depth: loop_depth)
            code << "\n"
          end
        end
      end

      code << "  out << #{nodev}\n"
      while loop_depth.positive?
        code << "  end\n"
        loop_depth -= 1
        nodev = "node#{depth - 1}"
        depth -= 1
      end

      code << "  out\nend\n"
      code
    end
  end
end
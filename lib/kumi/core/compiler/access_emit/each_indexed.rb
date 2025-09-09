# frozen_string_literal: true

module Kumi::Core::Compiler::AccessEmit
  module EachIndexed
    extend Base

    module_function

    def build(plan)
      policy     = plan.on_missing || :error
      key_policy = plan.key_policy || :indifferent
      path_key   = plan.path
      segs       = segment_ops(plan.operations)

      code = +"lambda do |data, &block|\n"
      code << "  out = []\n"
      code << "  node0 = data\n"
      code << "  idx_vec = []\n"
      nodev = "node0"
      depth = 0
      loop_depth = 0

      segs.each do |seg|
        if seg == :array
          code << "  #{array_guard_code(node_var: nodev, mode: :each_indexed, policy: policy, path_key: path_key, map_depth: loop_depth)}\n"
          code << "  ary#{loop_depth} = #{nodev}\n"
          code << "  len#{loop_depth} = ary#{loop_depth}.length\n"
          code << "  i#{loop_depth} = -1\n"
          code << "  while (i#{loop_depth} += 1) < len#{loop_depth}\n"
          code << "    idx_vec[#{loop_depth}] = i#{loop_depth}\n"
          child = "node#{depth + 1}"
          code << "    #{child} = ary#{loop_depth}[i#{loop_depth}]\n"
          nodev = child
          depth += 1
          loop_depth += 1
        else
          seg.each do |(_, key, preview)|
            code << fetch_hash_code(node_var: nodev, key: key, key_policy: key_policy,
                                    preview_array: preview, mode: :each_indexed, policy: policy,
                                    path_key: path_key, map_depth: loop_depth)
            code << "\n"
          end
        end
      end

      code << "  if block\n"
      code << "    block.call(#{nodev}, idx_vec.dup)\n"
      code << "  else\n"
      code << "    out << [#{nodev}, idx_vec.dup]\n"
      code << "  end\n"

      while loop_depth.positive?
        code << "  end\n"
        loop_depth -= 1
        nodev = "node#{depth - 1}"
        depth -= 1
      end

      code << "  block ? nil : out\nend\n"
      code
    end
  end
end

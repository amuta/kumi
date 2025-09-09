# frozen_string_literal: true

module Kumi::Core::Compiler::AccessEmit
  module Read
    extend Base

    module_function

    def build(plan)
      policy     = plan.on_missing || :error
      key_policy = plan.key_policy || :indifferent
      path_key   = plan.path
      ops        = plan.operations

      body = ops.map do |op|
        case op[:type]
        when :enter_hash
          fetch_hash_code(node_var: "node", key: op[:key], key_policy: key_policy,
                          preview_array: false, mode: :read, policy: policy,
                          path_key: path_key, map_depth: 0)
        when :enter_array
          %(raise TypeError, "Array encountered in :read accessor at '#{path_key}'")
        end
      end.join("\n      ")

      <<~RUBY
        lambda do |data|
          node = data
          #{body}
          node
        end
      RUBY
    end
  end
end

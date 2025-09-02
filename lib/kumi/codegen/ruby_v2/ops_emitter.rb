# frozen_string_literal: true

require_relative "name_mangler"

module Kumi
  module Codegen
    module RubyV2
      class OpsEmitter
        def initialize(plan_decl_by_name:, chain_const_by_input_name:)
          @plans  = plan_decl_by_name
          @chains = chain_const_by_input_name
        end

        def emit_ops_subset(decl_name, decl_spec, only_ids:, reduce_chain: false)
          ops = Array(decl_spec.fetch("operations")).select { |o| only_ids.include?(o.fetch("id")) }
          ops.flat_map { |op| emit_one_op(decl_name, decl_spec, op, reduce_chain: reduce_chain) }
        end

        def emit_body_for_decl(decl_name, decl_spec, skip_ids:, reduce_chain: false)
          decl_ops = Array(decl_spec.fetch("operations")).reject { |o| skip_ids.include?(o.fetch("id")) }
          lines    = decl_ops.flat_map { |op| emit_one_op(decl_name, decl_spec, op, reduce_chain: reduce_chain) }

          result_var =
            if decl_spec.key?("result")
              NameMangler.tmp_for_op(decl_spec["result"])
            else
              NameMangler.tmp_for_op(decl_ops.last.fetch("id"))
            end

          [lines, result_var]
        end

        private

        def emit_one_op(decl_name, decl_spec, op, reduce_chain: false)
          id = NameMangler.tmp_for_op(op.fetch("id"))
          case op.fetch("op")
          when "LoadInput"
            path = arg_path(op.fetch("args"))
            const = @chains.fetch(path)
            ["#{id} = __walk__(#{const}, input, cursors)"]
          when "Const"
            lit  = Array(op["args"]).first
            ["#{id} = #{JSON.generate(lit)}"]
          when "LoadDeclaration"
            target = (Array(op["args"]).first).to_s
            if inline?(decl_name, op.fetch("id"))
              # TODO: implement proper inline expansion
              ["#{id} = #{NameMangler.eval_method_for(target)}"]  # temporary: use method call
            else
              ["#{id} = self[:#{target}]"]
            end
          when "Map"
            fn   = op.fetch("attrs").fetch("fn")
            args = Array(op.fetch("args")).map { |ref| NameMangler.tmp_for_op(ref) }.join(", ")
            ["#{id} = __call_kernel__(#{fn.inspect}, #{args})"]
          when "ConstructTuple"
            tuple = Array(op.fetch("args")).map { |ref| NameMangler.tmp_for_op(ref) }.join(", ")
            ["#{id} = [#{tuple}]"]
          when "Select"
            condition = NameMangler.tmp_for_op(Array(op.fetch("args"))[0])
            true_val  = NameMangler.tmp_for_op(Array(op.fetch("args"))[1])
            false_val = NameMangler.tmp_for_op(Array(op.fetch("args"))[2])
            ["#{id} = (#{condition} ? #{true_val} : #{false_val})"]
          when "Reduce"
            raise "Reduce inside fused reduce_chain" if reduce_chain
            reduce_arg_id = Array(op.fetch("args")).first
            rp   = reduce_plan_for(decl_name, op.fetch("id"), reduce_arg_id)
            argv = NameMangler.tmp_for_op(reduce_arg_id)
            base_obj, key, axis = reduce_container(rp)
            reducer_fn = rp.fetch("reducer_fn")
            [
              "#{id} = nil",
              "__each_array__(#{base_obj}, #{key.inspect}) do |#{NameMangler.axis_var(axis)}|",
              "  cursors = cursors.merge(#{axis.inspect} => #{NameMangler.axis_var(axis)})",
              "  #{id} = #{id}.nil? ? #{argv} : __call_kernel__(#{reducer_fn.inspect}, #{id}, #{argv})",
              "end"
            ]
          else
            ["#{id} = (raise NotImplementedError, #{op["op"].inspect})"]
          end
        end

        def arg_path(arg)
          return arg.join(".") if arg.is_a?(Array)
          arg.to_s
        end

        def inline?(decl_name, op_id)
          decs = @plans.fetch(decl_name).fetch("inlining_decisions", {})
          (decs["op_#{op_id}"] && decs["op_#{op_id}"]["decision"] == "inline")
        end

        def reduce_plan_for(decl_name, reduce_op_id, reduce_arg_id)
          Array(@plans.fetch(decl_name).fetch("reduce_plans")).find { |rp| rp["op_id"] == reduce_arg_id } or
            raise KeyError, "reduce plan missing for #{decl_name} reduce op #{reduce_op_id} (looking for plan with op_id=#{reduce_arg_id})"
        end

        def reduce_container(rp)
          via  = Array(rp.fetch("via_path")).map(&:to_s)
          axis = rp.fetch("axis").to_s
          case via.length
          when 1
            ["input", via.first, axis]
          when 2
            [%(cursors[#{via.first.inspect}]), via.last, axis]
          when 3
            [%(cursors[#{via[1].inspect}]), via[2], axis]
          else
            raise NotImplementedError, "via_path depth #{via.length} not supported"
          end
        end
      end
    end
  end
end
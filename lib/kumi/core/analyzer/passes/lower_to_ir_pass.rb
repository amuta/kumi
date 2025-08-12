# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Lowers analyzed AST into Low-level IR for the VM
        #
        # INPUTS (from Analyzer state):
        # - :evaluation_order   → topologically sorted declaration names
        # - :declarations       → parsed & validated AST nodes
        # - :access_plans       → AccessPlanner output (plan id, scope, depth, mode, operations)
        # - :join_reduce_plans  → (optional) precomputed join/reduce strategy
        # - :input_metadata     → normalized InputMeta tree
        # - :scope_plans        → (optional) per-declaration scope hints
        #
        # OUTPUT:
        # - :ir_module (Kumi::Core::IR::Module) with IR decls
        #
        # RESPONSIBILITIES:
        # 1) Plan selection & LoadInput emission
        #    - Choose the correct plan id for each input path:
        #      * :read           → scalar fetch (no element traversal)
        #      * :ravel          → leaf values, flattened over path’s array lineage
        #      * :each_indexed   → vector fetch with hierarchical indices (for lineage)
        #      * :materialize    → preserves nested structure (used when required)
        #    - Set LoadInput attrs: scope:, is_scalar:, has_idx:
        #      * is_scalar = (mode == :read || mode == :materialize)
        #      * has_idx   = (mode == :each_indexed)
        #
        # 2) Shape tracking (SlotShape)
        #    - Track the kind of every slot: Scalar vs Vec(scope, has_idx)
        #    - Used to:
        #      * decide when to emit AlignTo (automatic vector alignment)
        #      * decide if the declaration needs a twin (:name__vec) + Lift
        #
        # 3) Automatic alignment for elementwise maps
        #    - For Map(fn, args...):
        #      * Find the carrier vector (max scope length among :elem params)
        #      * If another arg is a vector with a compatible prefix scope, insert AlignTo(to_scope: carrier_scope)
        #      * If incompatible, raise "cross-scope map without join"
        #
        # 4) Reducers & structure functions
        #    - Reducers (e.g., sum, min, max, avg, count_if) lower to Reduce on the first vector arg
        #    - Structure functions (e.g., size, flatten) are executed via Map unless explicitly marked reducer
        #
        # 5) Cascades & traits
        #    - CascadeExpression lowered to nested `if` (switch) form
        #    - Trait algebra remains purely boolean; no VM special-casing
        #
        # 6) Declaration twins & Lift
        #    - If the final expression shape is a Vec with indices:
        #      * Store to :name__vec (internal twin)
        #      * Emit Lift(to_scope: vec.scope) to regroup rows into nested arrays
        #      * Store lifted scalar to :name
        #    - If scalar result: store only :name
        #    - `DeclarationReference` resolves to :name__vec when a vector is required downstream
        #
        # INVARIANTS:
        # - All structural intent (vectorization, grouping, alignment) is decided during lowering.
        # - VM is mechanical; it does not sniff types or infer structure.
        # - AlignTo requires prefix-compatible scopes; otherwise we error early.
        # - Lift consumes a Vec with indices and returns a Scalar(nested_array) by grouping rows with `group_rows`.
        #
        # DEBUGGING:
        # - Set DEBUG_LOWER=1 to print per-declaration IR ops and alignment decisions.
        SlotShape = Struct.new(:kind, :scope, :has_idx) do
          def self.scalar
            new(:scalar, [], false)
          end

          def self.vec(scope, has_idx: true)
            new(:vec, Array(scope), has_idx)
          end
        end

        class LowerToIRPass < PassBase
          def run(errors)
            @vec_names = Set.new
            @vec_scopes = {}

            evaluation_order = get_state(:evaluation_order, required: true)
            declarations = get_state(:declarations, required: true)
            access_plans = get_state(:access_plans, required: true)
            join_reduce_plans = get_state(:join_reduce_plans, required: false) || {}
            input_metadata = get_state(:input_metadata, required: true)
            scope_plans = get_state(:scope_plans, required: false) || {}

            ir_decls = []

            evaluation_order.each do |name|
              decl = declarations[name]
              next unless decl

              begin
                scope_plan = scope_plans[name]
                ir_decl = lower_declaration(name, decl, access_plans, join_reduce_plans, scope_plan)
                ir_decls << ir_decl
              rescue StandardError => e
                location = decl.respond_to?(:loc) ? decl.loc : nil
                backtrace = e.backtrace.first(5).join("\n")
                message = "Failed to lower declaration #{name}: #{e.message}\n#{backtrace}"
                add_error(errors, location, "Failed to lower declaration #{name}: #{message}")
              end
            end

            ir_module = Kumi::Core::IR::Module.new(
              inputs: input_metadata,
              decls: ir_decls
            )

            if ENV["DEBUG_LOWER"]
              puts "DEBUG Lowered IR Module:"
              ir_module.decls.each do |decl|
                puts "  Declaration: #{decl.name} (#{decl.kind})"
                decl.ops.each_with_index do |op, i|
                  puts "    Op#{i}: #{op.tag} #{op.attrs.inspect} args=#{op.args.inspect}"
                end
              end
            end

            state.with(:ir_module, ir_module)
          end

          private

          def determine_slot_shape(slot, ops, access_plans)
            return SlotShape.scalar if slot.nil?

            op = ops[slot]

            case op.tag
            when :const
              SlotShape.scalar

            when :load_input
              if op.attrs[:is_scalar]
                SlotShape.scalar
              else
                plan_id = op.attrs[:plan_id]
                plan = access_plans.values.flatten.find { |p| p.accessor_key == plan_id }
                SlotShape.vec(op.attrs[:scope] || [], has_idx: plan&.mode == :each_indexed)
              end

            when :array
              arg_shapes = op.args.map { |i| determine_slot_shape(i, ops, access_plans) }
              return SlotShape.scalar if arg_shapes.all? { |s| s.kind == :scalar }

              carrier = arg_shapes.select { |s| s.kind == :vec }.max_by { |s| s.scope.length }
              SlotShape.vec(carrier.scope, has_idx: carrier.has_idx)

            when :map
              arg_shapes = op.args.map { |i| determine_slot_shape(i, ops, access_plans) }
              return SlotShape.scalar if arg_shapes.all? { |s| s.kind == :scalar }

              carrier = arg_shapes.select { |s| s.kind == :vec }.max_by { |s| s.scope.length }
              SlotShape.vec(carrier.scope, has_idx: carrier.has_idx)

            when :align_to
              SlotShape.vec(op.attrs[:to_scope], has_idx: true)

            when :reduce
              SlotShape.scalar
            when :lift
              SlotShape.scalar # lift groups to nested Ruby arrays
            when :switch
              branch_shapes =
                op.attrs[:cases].map { |(_, v)| determine_slot_shape(v, ops, access_plans) } +
                [determine_slot_shape(op.attrs[:default], ops, access_plans)]
              if (vec = branch_shapes.find { |s| s.kind == :vec })
                SlotShape.vec(vec.scope, has_idx: vec.has_idx)
              else
                SlotShape.scalar
              end

            when :ref
              name = op.attrs[:name]
              if @vec_scopes && (sc = @vec_scopes[name])
                SlotShape.vec(sc, has_idx: true)
              else
                SlotShape.scalar
              end
            else
              SlotShape.scalar
            end
          end

          def insert_align_to_if_needed(arg_slots, ops, access_plans, on_missing: :error)
            shapes = arg_slots.map { |s| determine_slot_shape(s, ops, access_plans) }

            vec_is = arg_slots.each_index.select { |i| shapes[i].kind == :vec }
            return arg_slots if vec_is.size < 2

            carrier_i = vec_is.max_by { |i| shapes[i].scope.length }
            carrier_scope = shapes[carrier_i].scope
            carrier_slot  = arg_slots[carrier_i]

            aligned = arg_slots.dup
            vec_is.each do |i|
              next if shapes[i].scope == carrier_scope

              short, long = [shapes[i].scope, carrier_scope].sort_by(&:length)
              unless long.first(short.length) == short
                raise "cross-scope map without join: #{shapes[i].scope.inspect} vs #{carrier_scope.inspect}"
              end

              src_slot = aligned[i] # <- chain on the current slot, not the original
              op = Kumi::Core::IR::Ops.AlignTo(
                carrier_slot, src_slot,
                to_scope: carrier_scope, require_unique: true, on_missing: on_missing
              )
              ops << op
              aligned[i] = ops.size - 1
            end

            aligned
          end

          def lower_declaration(name, decl, access_plans, join_reduce_plans, scope_plan)
            ops = []

            last_slot = lower_expression(decl.expression, ops, access_plans, scope_plan, need_indices = true, false)

            # shape of produced value
            shape = determine_slot_shape(last_slot, ops, access_plans)

            # after you compute `shape` and before storing
            if shape.kind == :vec && shape.has_idx
              @vec_names << name # ← add this
              vec_name = :"#{name}__vec"
              @vec_scopes[vec_name] = shape.scope # remember real scope

              ops << Kumi::Core::IR::Ops.Store(vec_name, last_slot)
              ops << Kumi::Core::IR::Ops.Lift(shape.scope, last_slot)
              last_slot += 1
              ops << Kumi::Core::IR::Ops.Store(name, last_slot)
            else
              ops << Kumi::Core::IR::Ops.Store(name, last_slot)
            end

            Kumi::Core::IR::Decl.new(
              name: name,
              kind: decl.is_a?(Syntax::ValueDeclaration) ? :value : :trait,
              shape: (shape.kind == :vec ? :vec : :scalar),
              ops: ops
            )
          end

          def lower_expression(expr, ops, access_plans, scope_plan, need_indices, top_level_has_reduce_plan = false)
            case expr
            when Syntax::Literal
              ops << Kumi::Core::IR::Ops.Const(expr.value)
              ops.size - 1

            when Syntax::InputReference
              # Handle simple input references (e.g., input.customer_tier)
              plan_id = pick_plan_id_for_input([expr.name], access_plans, scope_plan: scope_plan, need_indices: need_indices)

              # Get scope from the access plan
              plans = access_plans.fetch(expr.name.to_s, [])
              selected_plan = plans.find { |p| p.accessor_key == plan_id }
              scope = selected_plan ? selected_plan.scope : []
              is_scalar = selected_plan && %i[read ravel materialize].include?(selected_plan.mode)
              has_idx = selected_plan && selected_plan.mode == :each_indexed
              ops << Kumi::Core::IR::Ops.LoadInput(plan_id, scope: scope, is_scalar: is_scalar, has_idx: has_idx)
              ops.size - 1

            when Syntax::InputElementReference
              # Handle array element references (e.g., input.items.price)
              # Scope is determined by the path itself, not the declaration's scope
              plan_id = pick_plan_id_for_input(expr.path, access_plans, scope_plan: scope_plan, need_indices: need_indices)

              # Get scope from the access plan - it already has the correct scope calculated!
              path_str = expr.path.join(".")
              plans = access_plans.fetch(path_str, [])
              selected_plan = plans.find { |p| p.accessor_key == plan_id }

              # Use the scope from the access plan
              scope = selected_plan ? selected_plan.scope : []
              is_scalar = selected_plan && %i[read ravel materialize].include?(selected_plan.mode)
              has_idx = selected_plan && selected_plan.mode == :each_indexed

              ops << Kumi::Core::IR::Ops.LoadInput(plan_id, scope: scope, is_scalar: is_scalar, has_idx: has_idx)
              ops.size - 1

            when Syntax::DeclarationReference
              ref = @vec_names&.include?(expr.name) ? :"#{expr.name}__vec" : expr.name
              ops << Kumi::Core::IR::Ops.Ref(ref)
              ops.size - 1

            when Syntax::CallExpression
              entry = Kumi::Registry.entry(expr.fn_name)

              if entry&.structure_function
                # Treat args as whole collections, not element-wise
                arg_slots = expr.args.map { |a| lower_expression(a, ops, access_plans, scope_plan, false, false) }
                ops << Kumi::Core::IR::Ops.Map(expr.fn_name, arg_slots.size, *arg_slots)

                return ops.size - 1
              end

              if entry&.reducer
                # existing reducer branch (element-wise), needs indices
                arg_slots = expr.args.map { |a| lower_expression(a, ops, access_plans, scope_plan, true, false) }
                vec_i = arg_slots.index { |s| determine_slot_shape(s, ops, access_plans).kind == :vec }
                ops << if vec_i
                         Kumi::Core::IR::Ops.Reduce(expr.fn_name, [], [], [], arg_slots[vec_i])
                       else
                         Kumi::Core::IR::Ops.Map(expr.fn_name, arg_slots.size, *arg_slots)
                       end
                ops.size - 1

                # non-reducer, non-structure → your existing element-wise Map with align_to

                # # Pick the first vector arg to reduce over
                # vec_i = arg_slots.index { |s| determine_slot_shape(s, ops, access_plans).kind == :vec }

                # if vec_i
                #   # Reduce(fn, axis, result_scope, flatten_args, slot)
                #   ops << Kumi::Core::IR::Ops.Reduce(expr.fn_name, [], [], [], arg_slots[vec_i])
                #   ops.size - 1
                # else
                #   # All-scalar: just call it once (e.g., sum([..]) literal)
                #   ops << Kumi::Core::IR::Ops.Map(expr.fn_name, arg_slots.size, *arg_slots)
                #   ops.size - 1
                # end
                # Non-reducer: element-wise / structure path
              else
                arg_slots = expr.args.map { |a| lower_expression(a, ops, access_plans, scope_plan, need_indices, false) }
                aligned   = insert_align_to_if_needed(arg_slots, ops, access_plans, on_missing: :error)
                ops << Kumi::Core::IR::Ops.Map(expr.fn_name, expr.args.size, *aligned)
                ops.size - 1
              end

            when Syntax::ArrayExpression
              # Lower each element and collect into an array
              element_slots = expr.elements.map do |elem|
                lower_expression(elem, ops, access_plans, scope_plan, need_indices, false)
              end

              # Create array from the lowered elements
              ops << Kumi::Core::IR::Ops.Array(element_slots.size, *element_slots)
              ops.size - 1

            # LowerToIRPass#lower_expression
            when Syntax::CascadeExpression
              base_case = expr.cases.find { |c| c.condition.is_a?(Syntax::Literal) && c.condition.value == true }
              default_expr = base_case ? base_case.result : Kumi::Syntax::Literal.new(nil)
              branches = expr.cases.reject { |c| c.equal?(base_case) }

              # on c1, v1; on c2, v2; base b
              # => if(c1, v1, if(c2, v2, b))
              nested = branches.reverse.reduce(default_expr) do |else_part, c|
                Kumi::Syntax::CallExpression.new(:if, [c.condition, c.result, else_part])
              end

              lower_expression(nested, ops, access_plans, scope_plan, need_indices, false)

            else
              raise "Unsupported expression type: #{expr.class.name}"
            end
          end

          def lower_map(expr, ops, access_plans)
            entry  = Kumi::Registry.entry(expr.fn_name) or raise "unknown fn #{expr.fn_name}"
            modes  = param_modes_for(entry, expr.args.size) # must expand varargs, e.g. [:elem, :elem, :elem*]

            slots  = expr.args.map { |a| lower_expression(a, ops, access_plans, nil, false, false) }
            shapes = slots.map { |s| determine_slot_shape(s, ops, access_plans) }

            # reject illegal vec-in-:scalar params
            shapes.each_with_index do |sh, i|
              raise "vec supplied to scalar param #{i} for #{expr.fn_name}" if modes[i] == :scalar && sh.kind == :vec
            end

            # choose carrier among :elem vecs
            elem_vec_is = slots.each_index
                               .select { |i| modes[i] == :elem && shapes[i].kind == :vec }
            carrier_i = elem_vec_is.max_by { |i| shapes[i].scope.length }
            if carrier_i
              carrier_scope = shapes[carrier_i].scope
              aligned = slots.dup

              elem_vec_is.each do |i|
                next if shapes[i].scope == carrier_scope
                unless carrier_scope.first(shapes[i].scope.length) == shapes[i].scope
                  raise "cross-scope map without join: #{shapes[i].scope} vs #{carrier_scope}"
                end

                ops << Kumi::Core::IR::Ops.AlignTo(slots[carrier_i], slots[i], to_scope: carrier_scope)
                aligned[i] = ops.size - 1
              end

              ops << Kumi::Core::IR::Ops.Map(expr.fn_name, aligned.size, *aligned)
              ops.size - 1
            else
              # all-scalar or only :scalar params
              ops << Kumi::Core::IR::Ops.Map(expr.fn_name, slots.size, *slots)
              ops.size - 1
            end
          end

          def pick_plan_id_for_input(path, access_plans, scope_plan:, need_indices:)
            path_str = path.join(".")
            plans = access_plans.fetch(path_str) { raise "No access plan for #{path_str}" }
            depth = plans.first.depth
            if depth > 0
              mode = need_indices ? :each_indexed : :ravel
              plans.find { |p| p.mode == mode }&.accessor_key or
                raise("No #{mode.inspect} plan for #{path_str}")
            else
              plans.find { |p| p.mode == :read }&.accessor_key or
                raise("No :read plan for #{path_str}")
            end
          end

          def param_modes_for(entry, argc)
            pm = entry.param_modes
            return pm.call(argc) if pm.respond_to?(:call)

            fixed = pm.fetch(:fixed, [])
            if argc <= fixed.size
              fixed.first(argc)
            else
              fixed + Array.new(argc - fixed.size, pm.fetch(:variadic, :elem))
            end
          end
        end
      end
    end
  end
end

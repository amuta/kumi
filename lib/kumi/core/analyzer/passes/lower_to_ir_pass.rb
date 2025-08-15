# frozen_string_literal: true

require_relative "../../../support/ir_dump"
require_relative "../../ir/lowering/short_circuit_lowerer"

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
            @vec_meta = {}

            evaluation_order = get_state(:evaluation_order, required: true)
            declarations = get_state(:declarations, required: true)
            access_plans = get_state(:access_plans, required: true)
            join_reduce_plans = get_state(:join_reduce_plans, required: false) || {}
            input_metadata = get_state(:input_metadata, required: true)
            scope_plans = get_state(:scope_plans, required: false) || {}

            ir_decls = []

            @join_reduce_plans = join_reduce_plans
            @declarations = declarations

            evaluation_order.each do |name|
              decl = declarations[name]
              next unless decl

              begin
                scope_plan = scope_plans[name]
                @current_decl = name
                @lower_cache  = {} # reset per declaration

                ir_decl = lower_declaration(name, decl, access_plans, join_reduce_plans, scope_plan)
                ir_decls << ir_decl
              rescue StandardError => e
                location = decl.respond_to?(:loc) ? decl.loc : nil
                backtrace = e.backtrace.first(5).join("\n")
                message = "Failed to lower declaration #{name}: #{e.message}\n#{backtrace}"
                add_error(errors, location, "Failed to lower declaration #{name}: #{message}")
              end
            end

            if ENV["DEBUG_LOWER"]
              puts "DEBUG eval order: #{evaluation_order.inspect}"
              puts "DEBUG ir decl order: #{ir_decls.map(&:name).inspect}"
            end
            order_index = evaluation_order.each_with_index.to_h
            ir_decls.sort_by! { |d| order_index.fetch(d.name, Float::INFINITY) }

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

            if ENV["DUMP_IR"]
              # Collect analysis state that this pass actually uses
              analysis_state = {
                evaluation_order: evaluation_order,
                declarations: declarations,
                access_plans: access_plans,
                join_reduce_plans: join_reduce_plans,
                scope_plans: scope_plans,
                input_metadata: input_metadata,
                vec_names: @vec_names,
                vec_meta: @vec_meta,
                inferred_types: get_state(:inferred_types, required: false) || {}
              }

              pretty_ir = Kumi::Support::IRDump.pretty_print(ir_module, analysis_state: analysis_state)
              File.write(ENV["DUMP_IR"], pretty_ir)
              puts "DEBUG IR dumped to #{ENV['DUMP_IR']}"
            end

            state.with(:ir_module, ir_module)
          end

          private

          def short_circuit_lowerer
            @short_circuit_lowerer ||= Kumi::Core::IR::Lowering::ShortCircuitLowerer.new(
              shape_of: ->(slot) { determine_slot_shape(slot, [], {}) },
              registry: registry_v2
            )
          end

          def registry_v2
            @registry_v2 ||= Kumi::Core::Functions::RegistryV2.load_from_file
          end

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
              rs = Array(op.attrs[:result_scope] || [])
              rs.empty? ? SlotShape.scalar : SlotShape.vec(rs, has_idx: true)

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
              if (m = @vec_meta && @vec_meta[op.attrs[:name]])
                SlotShape.vec(m[:scope], has_idx: m[:has_idx])
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
            
            # Separate vectors into prefix-compatible and cross-scope groups
            prefix_compatible = []
            cross_scope_slots = []
            
            vec_is.each do |i|
              next if shapes[i].scope == carrier_scope

              short, long = [shapes[i].scope, carrier_scope].sort_by(&:length)
              if long.first(short.length) == short
                # Prefix-compatible: can use AlignTo
                prefix_compatible << i
              else
                # Cross-scope: needs Join
                cross_scope_slots << aligned[i]
              end
            end
            
            # Handle prefix-compatible vectors with AlignTo
            prefix_compatible.each do |i|
              src_slot = aligned[i] # <- chain on the current slot, not the original
              op = Kumi::Core::IR::Ops.AlignTo(
                carrier_slot, src_slot,
                to_scope: carrier_scope, require_unique: true, on_missing: on_missing
              )
              ops << op
              aligned[i] = ops.size - 1
            end
            
            # Handle cross-scope vectors with Join
            if cross_scope_slots.any?
              # Collect all cross-scope vector slots that need joining
              cross_scope_indices = []
              vec_is.each do |i|
                next if shapes[i].scope == carrier_scope
                next if prefix_compatible.include?(i)
                cross_scope_indices << i
              end
              
              # Add carrier to the list of slots to join
              carrier_i = vec_is.find { |i| shapes[i].scope == carrier_scope }
              join_slots = [aligned[carrier_i]] + cross_scope_indices.map { |i| aligned[i] }
              
              # Emit Join operation with zip policy
              join_op = Kumi::Core::IR::Ops.Join(*join_slots, policy: :zip, on_missing: on_missing)
              ops << join_op
              joined_slot = ops.size - 1
              
              # Create extract operations to decompose the joined result
              # Each original argument gets its own extract operation
              participating_indices = [carrier_i] + cross_scope_indices
              participating_indices.compact.each_with_index do |orig_i, extract_i|
                # Create an extract operation to pull the i-th component from the joined tuple
                extract_op = Kumi::Core::IR::Ops.Map(:__extract, 2, joined_slot, Kumi::Core::IR::Ops.Const(extract_i))
                ops << extract_op
                aligned[orig_i] = ops.size - 1
              end
            end

            aligned
          end

          def apply_scalar_to_vector_broadcast(scalar_slot, target_scope, ops, access_plans)
            # Create a carrier vector at the target scope by loading the appropriate input
            # For scope [:items], we need to load the items array to get the vector shape
            if target_scope.empty?
              puts "DEBUG: Empty target scope, returning scalar" if ENV["DEBUG_BROADCAST"]
              return scalar_slot # Can't broadcast to empty scope
            end

            # Create a load operation for the target scope to get vector shape
            # For [:items] scope, load the items array
            # Access plans are keyed by strings, not arrays
            if target_scope.length == 1
              input_key = target_scope.first.to_s
              plans = access_plans[input_key]
              puts "DEBUG: Looking for plans for #{input_key.inspect}, found: #{plans&.length || 0} plans" if ENV["DEBUG_BROADCAST"]
            else
              puts "DEBUG: Complex target scope #{target_scope.inspect}, not supported yet" if ENV["DEBUG_BROADCAST"]
              return scalar_slot
            end

            if plans&.any?
              # Find an indexed plan that gives us the vector shape
              indexed_plan = plans.find { |p| p.mode == :each_indexed }
              puts "DEBUG: Indexed plan found: #{indexed_plan.inspect}" if ENV["DEBUG_BROADCAST"] && indexed_plan
              if indexed_plan
                # Load the input to create a carrier vector
                ops << Kumi::Core::IR::Ops.LoadInput(indexed_plan.accessor_key, scope: indexed_plan.scope, has_idx: true)
                carrier_slot = ops.size - 1
                puts "DEBUG: Created carrier at slot #{carrier_slot}" if ENV["DEBUG_BROADCAST"]

                # Now broadcast scalar against the carrier - use first arg from carrier, rest from scalar
                ops << Kumi::Core::IR::Ops.Map(:if, 3, carrier_slot, scalar_slot, scalar_slot)
                result_slot = ops.size - 1
                puts "DEBUG: Created broadcast MAP at slot #{result_slot}" if ENV["DEBUG_BROADCAST"]
                result_slot
              else
                puts "DEBUG: No indexed plan found, returning scalar" if ENV["DEBUG_BROADCAST"]
                # No indexed plan available, return scalar as-is
                scalar_slot
              end
            else
              puts "DEBUG: No access plans found, returning scalar" if ENV["DEBUG_BROADCAST"]
              # No access plans for target scope, return scalar as-is
              scalar_slot
            end
          end

          def lower_declaration(name, decl, access_plans, join_reduce_plans, scope_plan)
            ops = []

            plan = @join_reduce_plans[name]
            req_scope =
              if plan && plan.respond_to?(:result_scope)
                Array(plan.result_scope) # [] for full reduction, [:players] for per-player, etc.
              elsif plan && plan.respond_to?(:policy) && plan.policy == :broadcast
                Array(plan.target_scope) # Broadcast to target scope
              elsif top_level_reducer?(decl)
                [] # collapse all axes by default
              else
                scope_plan&.scope # fallback (vector values, arrays, etc.)
              end

            last_slot = lower_expression(decl.expression, ops, access_plans, scope_plan,
                                         need_indices = true, req_scope)

            # Apply broadcasting for scalar-to-vector join plans
            if plan && plan.respond_to?(:policy) && plan.policy == :broadcast
              puts "DEBUG: Applying scalar broadcast for #{name} to scope #{plan.target_scope.inspect}" if ENV["DEBUG_BROADCAST"]
              last_slot = apply_scalar_to_vector_broadcast(last_slot, plan.target_scope, ops, access_plans)
              puts "DEBUG: Broadcast result slot: #{last_slot}" if ENV["DEBUG_BROADCAST"]
            end

            shape = determine_slot_shape(last_slot, ops, access_plans)
            puts "DEBUG: Shape after broadcast for #{name}: #{shape.inspect}" if ENV["DEBUG_BROADCAST"]

            if shape.kind == :vec
              vec_name = :"#{name}__vec"
              @vec_meta[vec_name] = { scope: shape.scope, has_idx: shape.has_idx }

              # internal twin for downstream refs
              ops << Kumi::Core::IR::Ops.Store(vec_name, last_slot)

              # public presentation
              ops << if shape.has_idx
                       Kumi::Core::IR::Ops.Lift(shape.scope, last_slot)
                     else
                       Kumi::Core::IR::Ops.Reduce(:to_array, [], [], [], last_slot)
                     end
              last_slot = ops.size - 1
            end

            # ➌ store public name (scalar or transformed vec)
            ops << Kumi::Core::IR::Ops.Store(name, last_slot)

            Kumi::Core::IR::Decl.new(
              name: name,
              kind: decl.is_a?(Syntax::ValueDeclaration) ? :value : :trait,
              shape: (shape.kind == :vec ? :vec : :scalar),
              ops: ops
            )
          end

          # Lowers an analyzed AST node into IR ops and returns the slot index.
          # - ops: mutable IR ops array (per-declaration)
          # - need_indices: whether to prefer :each_indexed plan for inputs
          # - required_scope: consumer-required scope (guides grouped reductions)
          # - cacheable: whether this lowering may be cached (branch bodies under guards: false)
          def lower_expression(expr, ops, access_plans, scope_plan, need_indices, required_scope = nil, cacheable: true)
            @lower_cache ||= {}
            key = [@current_decl, expr.object_id, Array(required_scope), !!need_indices]
            if cacheable && (hit = @lower_cache[key])
              return hit
            end

            if ENV["DEBUG_LOWER"] && expr.is_a?(Syntax::CallExpression)
              puts "  LOWER_EXPR[#{@current_decl}] #{expr.fn_name}(#{expr.args.size} args) req_scope=#{required_scope.inspect}"
            end

            slot =
              case expr
              when Syntax::Literal
                ops << Kumi::Core::IR::Ops.Const(expr.value)
                ops.size - 1

              when Syntax::InputReference
                plan_id = pick_plan_id_for_input([expr.name], access_plans,
                                                 scope_plan: scope_plan, need_indices: need_indices)
                
                plans    = access_plans.fetch(expr.name.to_s, [])
                selected = plans.find { |p| p.accessor_key == plan_id }
                scope    = selected ? selected.scope : []
                is_scalar = selected && %i[read materialize].include?(selected.mode)
                has_idx   = selected && selected.mode == :each_indexed
                ops << Kumi::Core::IR::Ops.LoadInput(plan_id, scope: scope, is_scalar: is_scalar, has_idx: has_idx)
                ops.size - 1

              when Syntax::InputElementReference
                plan_id = pick_plan_id_for_input(expr.path, access_plans,
                                                 scope_plan: scope_plan, need_indices: need_indices)
                path_str = expr.path.join(".")
                plans    = access_plans.fetch(path_str, [])
                selected = plans.find { |p| p.accessor_key == plan_id }
                scope    = selected ? selected.scope : []
                is_scalar = selected && %i[read materialize].include?(selected.mode)
                has_idx   = selected && selected.mode == :each_indexed
                ops << Kumi::Core::IR::Ops.LoadInput(plan_id, scope: scope, is_scalar: is_scalar, has_idx: has_idx)
                ops.size - 1

              when Syntax::DeclarationReference
                # Check if this declaration has a vectorized twin at the required scope
                twin = :"#{expr.name}__vec"
                twin_meta = @vec_meta && @vec_meta[twin]

                if required_scope && !Array(required_scope).empty?
                  # Consumer needs a grouped view of this declaration.
                  if twin_meta && twin_meta[:scope] == Array(required_scope)
                    # We have a vectorized twin at exactly the required scope - use it!
                    ops << Kumi::Core::IR::Ops.Ref(twin)
                    return ops.size - 1
                  else
                    # Need to inline re-lower the referenced declaration's *expression*,
                    # forcing indices, and grouping to the requested scope.
                    decl = @declarations.fetch(expr.name) { raise "unknown decl #{expr.name}" }
                    slot = lower_expression(decl.expression, ops, access_plans, scope_plan,
                                            true,                    # need_indices (grouping requires indexed source)
                                            required_scope,          # group-to scope
                                            cacheable: true)         # per-decl slot cache will dedupe
                    return slot
                  end
                else
                  # Plain (scalar) use, or already-materialized vec twin
                  ref  = twin_meta ? twin : expr.name
                  ops << Kumi::Core::IR::Ops.Ref(ref)
                  return ops.size - 1
                end

              when Syntax::CallExpression
                qualified_fn_name = get_qualified_function_name(expr)
                entry = Kumi::Registry.entry(qualified_fn_name)

                # Validate signature metadata from FunctionSignaturePass (read-only assertions)
                validate_signature_metadata(expr, entry)

                # Constant folding optimization: evaluate expressions with all literal arguments
                if can_constant_fold?(expr, entry)
                  folded_value = constant_fold(expr, entry)
                  ops << Kumi::Core::IR::Ops.Const(folded_value)
                  return ops.size - 1
                end

                # Trait-driven short-circuit lowering for and/or
                qualified_fn_name = get_qualified_function_name(expr)
                if short_circuit_lowerer.short_circuit?(qualified_fn_name)
                  return lower_short_circuit_bool(expr, ops, access_plans, scope_plan, need_indices, required_scope, cacheable)
                end

                if ENV["DEBUG_LOWER"] && has_nested_reducer?(expr)
                  puts "  NESTED_REDUCER_DETECTED in #{expr.fn_name} with req_scope=#{required_scope.inspect}"
                end

                # Special handling for comparison operations containing nested reductions
                if !entry&.reducer && has_nested_reducer?(expr)
                  puts "  SPECIAL_NESTED_REDUCTION_HANDLING for #{expr.fn_name}" if ENV["DEBUG_LOWER"]

                  # For comparison ops with nested reducers, we need to ensure
                  # the nested reducer gets the right required_scope (per-player)
                  # instead of the full dimensional scope from infer_expr_scope

                  # Get the desired result scope from our scope plan (per-player scope)
                  # This should be [:players] for per-player operations
                  plan = @join_reduce_plans[@current_decl]
                  target_scope = if plan.is_a?(Kumi::Core::Analyzer::Plans::Reduce) && plan.result_scope && !plan.result_scope.empty?
                                   plan.result_scope
                                 elsif required_scope && !required_scope.empty?
                                   required_scope
                                 else
                                   # Try to infer per-player scope from the nested reducer argument
                                   nested_reducer_arg = find_nested_reducer_arg(expr)
                                   if nested_reducer_arg
                                     infer_per_player_scope(nested_reducer_arg)
                                   else
                                     []
                                   end
                                 end

                  puts "  NESTED_REDUCTION target_scope=#{target_scope.inspect}" if ENV["DEBUG_LOWER"]

                  # Lower arguments with the correct scope for nested reducers
                  arg_slots = expr.args.map do |a|
                    lower_expression(a, ops, access_plans, scope_plan,
                                     need_indices, target_scope, cacheable: cacheable)
                  end

                  aligned = target_scope.empty? ? arg_slots : insert_align_to_if_needed(arg_slots, ops, access_plans, on_missing: :error)
                  qualified_fn_name = get_qualified_function_name(expr)
                  ops << Kumi::Core::IR::Ops.Map(qualified_fn_name, expr.args.size, *aligned)
                  return ops.size - 1

                elsif entry&.reducer
                  # Need indices iff grouping is requested
                  child_need_idx = !Array(required_scope).empty?

                  arg_slots = expr.args.map do |a|
                    lower_expression(a, ops, access_plans, scope_plan,
                                     child_need_idx,                  # <<< important
                                     nil,                             # children of reducer don't inherit grouping
                                     cacheable: true)
                  end
                  vec_i = arg_slots.index { |s| determine_slot_shape(s, ops, access_plans).kind == :vec }
                  if vec_i
                    src_slot  = arg_slots[vec_i]
                    src_shape = determine_slot_shape(src_slot, ops, access_plans)

                    # If grouping requested but source lacks indices (e.g. cached ravel), reload it with indices
                    if !Array(required_scope).empty? && !src_shape.has_idx
                      src_slot  = lower_expression(expr.args[vec_i], ops, access_plans, scope_plan,
                                                   true, # force indices
                                                   nil,
                                                   cacheable: true)
                      src_shape = determine_slot_shape(src_slot, ops, access_plans)
                    end

                    if ENV["DEBUG_LOWER"]
                      puts "  emit_reduce(#{expr.fn_name}, #{src_slot}, #{src_shape.scope.inspect}, #{Array(required_scope).inspect})"
                    end
                    return emit_reduce(ops, expr.fn_name, src_slot, src_shape.scope, required_scope)
                  else
                    qualified_fn_name = get_qualified_function_name(expr)
                    ops << Kumi::Core::IR::Ops.Map(qualified_fn_name, arg_slots.size, *arg_slots)
                    return ops.size - 1
                  end
                end

                # non-reducer path unchanged…

                # Non-reducer: pointwise. Choose carrier = deepest vec among args.
                target = infer_expr_scope(expr, access_plans) # static, no ops emitted
                
                # 0) collect signature metadata (if present)
                node_index = get_state(:node_index, required: false)
                node_meta  = node_index && node_index[expr.object_id] && node_index[expr.object_id][:metadata]
                join_policy = node_meta && node_meta[:join_policy] # nil | :zip | :product
                
                if ENV["DEBUG_LOWER"]
                  puts "    node_index available: #{!!node_index}"
                  puts "    node_meta: #{node_meta.inspect}" if node_meta
                  puts "    join_policy: #{join_policy.inspect}"
                end

                # 1) lower args as before
                arg_slots = expr.args.map do |a|
                  lower_expression(a, ops, access_plans, scope_plan,
                                   need_indices, target, cacheable: cacheable)
                end

                # 2) align using extracted component
                shape_of = ->(slot) { determine_slot_shape(slot, ops, access_plans) }
                aligner  = Kumi::Core::IR::Lowering::ArgAligner.new(shape_of: shape_of)
                aligned  = aligner.align!(ops: ops, arg_slots: arg_slots, join_policy: join_policy, on_missing: :error).slots

                if ENV["DEBUG_LOWER"]
                  puts "  MAP #{expr.fn_name} with #{aligned.size} args: #{aligned.inspect}"
                  puts "    join_policy: #{join_policy.inspect}"
                end

                # 3) map
                qualified_fn_name = get_qualified_function_name(expr)
                ops << Kumi::Core::IR::Ops.Map(qualified_fn_name, expr.args.size, *aligned)
                ops.size - 1

              when Syntax::ArrayExpression
                target = infer_expr_scope(expr, access_plans) # LUB across children
                puts "DEBUG array target scope=#{target.inspect}" if ENV["DEBUG_LOWER"]
                elem_slots = expr.elements.map do |e|
                  lower_expression(e, ops, access_plans, scope_plan,
                                   need_indices,                   # pass-through
                                   target,                         # <<< required_scope = target
                                   cacheable: true)
                end
                elem_slots = insert_align_to_if_needed(elem_slots, ops, access_plans, on_missing: :error) unless target.empty?
                ops << Kumi::Core::IR::Ops.Array(elem_slots.size, *elem_slots)
                return ops.size - 1

              when Syntax::CascadeExpression
                # Find a base (true) case, if present
                base_case    = expr.cases.find { |c| c.condition.is_a?(Syntax::Literal) && c.condition.value == true }
                default_expr = base_case ? base_case.result : Kumi::Syntax::Literal.new(nil)
                branches     = expr.cases.reject { |c| c.equal?(base_case) }

                # Lower each condition once to probe shapes (cacheable)
                precond_slots  = branches.map do |c|
                  lower_expression(c.condition, ops, access_plans, scope_plan,
                                   need_indices, nil, cacheable: cacheable)
                end
                precond_shapes = precond_slots.map { |s| determine_slot_shape(s, ops, access_plans) }
                vec_cond_is    = precond_shapes.each_index.select { |i| precond_shapes[i].kind == :vec }

                # Tiny helpers for boolean maps
                map1 = lambda { |fn, a|
                  ops << Kumi::Core::IR::Ops.Map(fn, 1, a)
                  ops.size - 1
                }
                map2 = lambda { |fn, a, b|
                  ops << Kumi::Core::IR::Ops.Map(fn, 2, a, b)
                  ops.size - 1
                }

                if vec_cond_is.empty?
                  # ------------------------------------------------------------------
                  # SCALAR CASCADE (lazy): evaluate branch bodies under guards
                  # ------------------------------------------------------------------
                  any_prev_true = lower_expression(Kumi::Syntax::Literal.new(false), ops, access_plans,
                                                   scope_plan, need_indices, nil, cacheable: false)

                  cases_attr = [] # [[cond_slot, value_slot], ...]

                  branches.each_with_index do |c, i|
                    not_any = map1.call(:not, any_prev_true)
                    guard_i = map2.call(:and, not_any, precond_slots[i])

                    ops << Kumi::Core::IR::Ops.GuardPush(guard_i)
                    val_slot = lower_expression(c.result, ops, access_plans, scope_plan,
                                                need_indices, nil, cacheable: false)
                    ops << Kumi::Core::IR::Ops.GuardPop

                    cases_attr << [precond_slots[i], val_slot]
                    any_prev_true = map2.call(:or, any_prev_true, precond_slots[i])
                  end

                  not_any = map1.call(:not, any_prev_true)
                  ops << Kumi::Core::IR::Ops.GuardPush(not_any)
                  default_slot = lower_expression(default_expr, ops, access_plans, scope_plan,
                                                  need_indices, nil, cacheable: false)
                  ops << Kumi::Core::IR::Ops.GuardPop

                  ops << Kumi::Core::IR::Ops.Switch(cases_attr, default_slot)
                  ops.size - 1
                else
                  # -------------------------
                  # VECTOR CASCADE (per-row lazy)
                  # -------------------------

                  # First lower raw conditions to peek at shapes.
                  raw_cond_slots = branches.map do |c|
                    lower_expression(c.condition, ops, access_plans, scope_plan,
                                     need_indices, nil, cacheable: true)
                  end
                  raw_shapes     = raw_cond_slots.map { |s| determine_slot_shape(s, ops, access_plans) }
                  vec_is         = raw_shapes.each_index.select { |i| raw_shapes[i].kind == :vec }

                  # Choose cascade_scope: prefer scope_plan (from scope resolution),
                  # fallback to LUB of vector condition scopes.
                  if scope_plan && !scope_plan.scope.nil? && !scope_plan.scope.empty?
                    cascade_scope = Array(scope_plan.scope)
                  else
                    candidate_scopes = vec_is.map { |i| raw_shapes[i].scope }
                    cascade_scope    = lub_scopes(candidate_scopes)
                    cascade_scope    = [] if cascade_scope.nil?
                  end

                  # Re-lower each condition *properly* at cascade_scope (reproject deeper ones).
                  conds_at_scope = branches.map do |c|
                    lower_cascade_pred(c.condition, cascade_scope, ops, access_plans, scope_plan)
                  end

                  # Booleans utilities
                  map1 = lambda { |fn, a|
                    ops << Kumi::Core::IR::Ops.Map(fn, 1, a)
                    ops.size - 1
                  }
                  map2 = lambda { |fn, a, b|
                    ops << Kumi::Core::IR::Ops.Map(fn, 2, a, b)
                    ops.size - 1
                  }

                  # Build lazy guards per branch at cascade_scope
                  any_prev = lower_expression(Kumi::Syntax::Literal.new(false), ops, access_plans,
                                              scope_plan, need_indices, nil, cacheable: false)
                  val_slots = []

                  branches.each_with_index do |c, i|
                    not_prev = map1.call(:not, any_prev)
                    need_i = map2.call(:and, not_prev, conds_at_scope[i]) # @ cascade_scope

                    ops << Kumi::Core::IR::Ops.GuardPush(need_i)
                    vslot = lower_expression(c.result, ops, access_plans, scope_plan,
                                             need_indices, cascade_scope, cacheable: false)
                    # ensure vector results live at cascade_scope
                    vslot = align_to_cascade_if_vec(vslot, cascade_scope, ops, access_plans)
                    ops << Kumi::Core::IR::Ops.GuardPop

                    val_slots << vslot
                    any_prev = map2.call(:or, any_prev, conds_at_scope[i]) # still @ cascade_scope
                  end

                  # Default branch
                  not_prev = map1.call(:not, any_prev)
                  ops << Kumi::Core::IR::Ops.GuardPush(not_prev)
                  default_slot = lower_expression(default_expr, ops, access_plans, scope_plan,
                                                  need_indices, cascade_scope, cacheable: false)
                  default_slot = align_to_cascade_if_vec(default_slot, cascade_scope, ops, access_plans)
                  ops << Kumi::Core::IR::Ops.GuardPop

                  # Assemble via nested element-wise selection
                  nested = default_slot
                  (branches.length - 1).downto(0) do |i|
                    ops << Kumi::Core::IR::Ops.Map(:if, 3, conds_at_scope[i], val_slots[i], nested)
                    nested = ops.size - 1
                  end
                  nested

                end

              else
                raise "Unsupported expression type: #{expr.class.name}"
              end

            @lower_cache[key] = slot if cacheable
            slot
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

          def align_to_cascade_if_vec(slot, cascade_scope, ops, access_plans)
            sh = determine_slot_shape(slot, ops, access_plans)
            return slot if sh.kind == :scalar && cascade_scope.empty? # scalar cascade, keep scalar
            return slot if sh.scope == cascade_scope

            # Handle scalar-to-vector broadcasting for vectorized cascades
            if sh.kind == :scalar && !cascade_scope.empty?
              # Find a carrier vector at cascade scope to broadcast scalar against
              target_slot = nil
              ops.each_with_index do |op, i|
                next unless %i[load_input map].include?(op.tag)

                shape = determine_slot_shape(i, ops, access_plans)
                if shape.kind == :vec && shape.scope == cascade_scope && shape.has_idx
                  target_slot = i
                  break
                end
              end

              raise "Cannot broadcast scalar to cascade scope #{cascade_scope.inspect} - no carrier vector found" unless target_slot

              # Use MAP with a special broadcast function - but first I need to create one
              # For now, let's try using the 'if' function to broadcast: if(true, scalar, carrier) -> broadcasts scalar
              const_true = ops.size
              ops << Kumi::Core::IR::Ops.Const(true)

              ops << Kumi::Core::IR::Ops.Map(:if, 3, const_true, slot, target_slot)
              return ops.size - 1

              # No carrier found, can't broadcast

            end

            short, long = [sh.scope, cascade_scope].sort_by(&:length)
            unless long.first(short.length) == short
              raise "cascade branch result scope #{sh.scope.inspect} not compatible with cascade scope #{cascade_scope.inspect}"
            end

            raise "unsupported cascade scope #{cascade_scope.inspect} for slot #{slot}" if cascade_scope.empty?
          end

          def prefix?(short, long)
            long.first(short.length) == short
          end

          def infer_expr_scope(expr, access_plans)
            case expr
            when Syntax::DeclarationReference
              meta = @vec_meta && @vec_meta[:"#{expr.name}__vec"]
              meta ? Array(meta[:scope]) : []
            when Syntax::InputElementReference
              key  = expr.path.join(".")
              plan = access_plans.fetch(key, []).find { |p| p.mode == :each_indexed }
              plan ? Array(plan.scope) : []
            when Syntax::InputReference
              plans = access_plans.fetch(expr.name.to_s, [])
              plan  = plans.find { |p| p.mode == :each_indexed }
              plan ? Array(plan.scope) : []
            when Syntax::CallExpression
              # reducers: use source vec scope; non-reducers: deepest carrier among args
              scopes = expr.args.map { |a| infer_expr_scope(a, access_plans) }
              scopes.max_by(&:length) || []
            when Syntax::ArrayExpression
              scopes = expr.elements.map { |e| infer_expr_scope(e, access_plans) }
              lub_scopes(scopes) # <-- important
            else
              []
            end
          end

          def lower_cascade_pred(cond, cascade_scope, ops, access_plans, scope_plan)
            case cond
            when Syntax::DeclarationReference
              # Check if this declaration has a vectorized twin at the required scope
              twin = :"#{cond.name}__vec"
              twin_meta = @vec_meta && @vec_meta[twin]

              if cascade_scope && !Array(cascade_scope).empty?
                # Consumer needs a grouped view of this declaration.
                if twin_meta && twin_meta[:scope] == Array(cascade_scope)
                  # We have a vectorized twin at exactly the required scope - use it!
                  ops << Kumi::Core::IR::Ops.Ref(twin)
                  ops.size - 1
                else
                  # Need to inline re-lower the referenced declaration's *expression*
                  decl = @declarations.fetch(cond.name) { raise "unknown decl #{cond.name}" }
                  slot = lower_expression(decl.expression, ops, access_plans, scope_plan,
                                          true, Array(cascade_scope), cacheable: true)
                  project_mask_to_scope(slot, cascade_scope, ops, access_plans)
                end
              else
                # Plain (scalar) use, or already-materialized vec twin
                ref = twin_meta ? twin : cond.name
                ops << Kumi::Core::IR::Ops.Ref(ref)
                ops.size - 1
              end

            when Syntax::CallExpression
              if cond.fn_name == :cascade_and
                parts = cond.args.map { |a| lower_cascade_pred(a, cascade_scope, ops, access_plans, scope_plan) }
                # They’re all @ cascade_scope (or scalar) now; align scalars broadcast, vecs already match.
                parts.reduce do |acc, s|
                  ops << Kumi::Core::IR::Ops.Map(:and, 2, acc, s)
                  ops.size - 1
                end
              else
                slot = lower_expression(cond, ops, access_plans, scope_plan,
                                        true, Array(cascade_scope), cacheable: false)
                project_mask_to_scope(slot, cascade_scope, ops, access_plans)
              end

            else
              slot = lower_expression(cond, ops, access_plans, scope_plan,
                                      true, Array(cascade_scope), cacheable: false)
              project_mask_to_scope(slot, cascade_scope, ops, access_plans)
            end
          end

          def common_prefix(a, b)
            a = Array(a)
            b = Array(b)
            i = 0
            i += 1 while i < a.length && i < b.length && a[i] == b[i]
            a.first(i)
          end

          def lub_scopes(scopes)
            scopes = scopes.reject { |s| s.nil? || s.empty? }
            return [] if scopes.empty?

            scopes.reduce(scopes.first) { |acc, s| common_prefix(acc, s) }
          end

          def emit_reduce(ops, fn_name, src_slot, src_scope, required_scope)
            rs = Array(required_scope || [])
            ss = Array(src_scope)

            # No-op: grouping to full source scope
            return src_slot if !rs.empty? && rs == ss

            axis = rs.empty? ? ss : (ss - rs)
            puts "  emit_reduce #{fn_name} on #{src_slot} with axis #{axis.inspect} and result scope #{rs.inspect}" if ENV["DEBUG_LOWER"]
            ops << Kumi::Core::IR::Ops.Reduce(fn_name, axis, rs, [], src_slot)
            ops.size - 1
          end

          def vec_twin_name(base, scope)
            scope_tag = Array(scope).map(&:to_s).join("_") # e.g. "players"
            :"#{base}__vec__#{scope_tag}"
          end

          def find_vec_twin(name, scope)
            t = vec_twin_name(name, scope)
            @vec_meta[t] ? t : nil
          end

          def top_level_reducer?(decl)
            ce = decl.expression
            return false unless ce.is_a?(Kumi::Syntax::CallExpression)

            entry = Kumi::Registry.entry(ce.fn_name)
            entry&.reducer && !entry&.structure_function
          end

          def has_nested_reducer?(expr)
            return false unless expr.is_a?(Kumi::Syntax::CallExpression)

            expr.args.any? do |arg|
              case arg
              when Kumi::Syntax::CallExpression
                entry = Kumi::Registry.entry(arg.fn_name)
                return true if entry&.reducer

                has_nested_reducer?(arg) # recursive check
              else
                false
              end
            end
          end

          def find_nested_reducer_arg(expr)
            return nil unless expr.is_a?(Kumi::Syntax::CallExpression)

            expr.args.each do |arg|
              case arg
              when Kumi::Syntax::CallExpression
                entry = Kumi::Registry.entry(arg.fn_name)
                return arg if entry&.reducer

                nested = find_nested_reducer_arg(arg)
                return nested if nested
              end
            end
            nil
          end

          def infer_per_player_scope(reducer_expr)
            return [] unless reducer_expr.is_a?(Kumi::Syntax::CallExpression)

            # Look at the reducer's argument to determine the full scope
            arg = reducer_expr.args.first
            return [] unless arg

            case arg
            when Kumi::Syntax::InputElementReference
              # For paths like [:players, :score_matrices, :session, :points]
              # We want to keep [:players] and reduce over the rest
              arg.path.empty? ? [] : [arg.path.first]
            when Kumi::Syntax::CallExpression
              # For nested expressions, get the deepest input path and take first element
              deepest = find_deepest_input_path(arg)
              deepest && !deepest.empty? ? [deepest.first] : []
            else
              []
            end
          end

          def find_deepest_input_path(expr)
            case expr
            when Kumi::Syntax::InputElementReference
              expr.path
            when Kumi::Syntax::InputReference
              [expr.name]
            when Kumi::Syntax::CallExpression
              paths = expr.args.map { |a| find_deepest_input_path(a) }.compact
              paths.max_by(&:length)
            else
              nil
            end
          end

          # Make sure a boolean mask lives at exactly cascade_scope.
          def project_mask_to_scope(slot, cascade_scope, ops, access_plans)
            sh = determine_slot_shape(slot, ops, access_plans)
            return slot if sh.scope == cascade_scope

            # If we have a scalar condition but need it at cascade scope, broadcast it
            if sh.kind == :scalar && cascade_scope && !Array(cascade_scope).empty?
              # Find a target vector that already has the cascade scope
              target_slot = nil
              ops.each_with_index do |op, i|
                next unless %i[load_input map].include?(op.tag)

                shape = determine_slot_shape(i, ops, access_plans)
                if shape.kind == :vec && shape.scope == Array(cascade_scope) && shape.has_idx
                  target_slot = i
                  break
                end
              end

              return slot unless target_slot

              ops << Kumi::Core::IR::Ops.AlignTo(target_slot, slot, to_scope: Array(cascade_scope), on_missing: :error,
                                                                    require_unique: true)
              return ops.size - 1

              # Can't broadcast, use as-is

            end

            return slot if sh.kind == :scalar

            cascade_scope = Array(cascade_scope)
            slot_scope = Array(sh.scope)

            # Check prefix compatibility
            short, long = [cascade_scope, slot_scope].sort_by(&:length)
            unless long.first(short.length) == short
              raise "cascade condition scope #{slot_scope.inspect} is not prefix-compatible with #{cascade_scope.inspect}"
            end

            if slot_scope.length < cascade_scope.length
              # Need to broadcast UP: slot scope is shorter, needs to be aligned to cascade scope
              # Find a target vector that already has the cascade scope
              target_slot = nil
              ops.each_with_index do |op, i|
                next unless %i[load_input map].include?(op.tag)

                shape = determine_slot_shape(i, ops, access_plans)
                if shape.kind == :vec && shape.scope == cascade_scope && shape.has_idx
                  target_slot = i
                  break
                end
              end

              if target_slot
                ops << Kumi::Core::IR::Ops.AlignTo(target_slot, slot, to_scope: cascade_scope, on_missing: :error, require_unique: true)
                ops.size - 1
              else
                # Fallback: use the slot itself (might not work but worth trying)
                ops << Kumi::Core::IR::Ops.AlignTo(slot, slot, to_scope: cascade_scope, on_missing: :error, require_unique: true)
                ops.size - 1
              end
            else
              # Need to reduce DOWN: slot scope is longer, reduce extra dimensions
              extra_axes = slot_scope - cascade_scope
              if extra_axes.empty?
                slot # should not happen due to early return above
              else
                ops << Kumi::Core::IR::Ops.Reduce(:any?, extra_axes, cascade_scope, [], slot)
                ops.size - 1
              end
            end
          end

          # Constant folding optimization helpers
          def can_constant_fold?(expr, entry)
            return false unless entry&.fn # Skip if function not found
            return false if entry.reducer # Skip reducer functions for now
            return false if expr.args.empty? # Need at least one argument
            
            # Check if all arguments are literals
            expr.args.all? { |arg| arg.is_a?(Syntax::Literal) }
          end

          def validate_signature_metadata(expr, entry)
            # Get the node index to access signature metadata  
            node_index = get_state(:node_index, required: false)
            return unless node_index
            
            node_entry = node_index[expr.object_id]
            return unless node_entry
            
            metadata = node_entry[:metadata]
            return unless metadata
            
            # Validate that dropped axes make sense for reduction functions
            if entry&.reducer && metadata[:dropped_axes]
              dropped_axes = metadata[:dropped_axes] 
              unless dropped_axes.is_a?(Array)
                raise "Invalid dropped_axes metadata for reducer #{expr.fn_name}: expected Array, got #{dropped_axes.class}"
              end
              
              # For reductions, we should have at least one dropped axis (or empty for scalar reductions)
              if ENV["DEBUG_LOWER"]
                puts "  SIGNATURE[#{expr.fn_name}] dropped_axes: #{dropped_axes.inspect}"
              end
            end
            
            # Validate join_policy is recognized
            if metadata[:join_policy] && ![:zip, :product].include?(metadata[:join_policy])
              raise "Invalid join_policy for #{expr.fn_name}: #{metadata[:join_policy].inspect}"
            end
            
            # Warn about join_policy when no join op exists yet (future integration point)  
            if metadata[:join_policy] && ENV["DEBUG_LOWER"]
              puts "  SIGNATURE[#{expr.fn_name}] join_policy: #{metadata[:join_policy]} (join op not yet implemented)"
            end
          end

          def constant_fold(expr, entry)
            literal_values = expr.args.map(&:value)
            
            begin
              # Call the function with literal values at compile time
              entry.fn.call(*literal_values)
            rescue StandardError => e
              # If constant folding fails, fall back to runtime evaluation
              # This shouldn't happen with pure functions, but be defensive
              puts "Constant folding failed for #{expr.fn_name}: #{e.message}" if ENV["DEBUG_LOWER"]
              raise "Cannot constant fold #{expr.fn_name}: #{e.message}"
            end
          end

          # Get the qualified function name from metadata, fallback to node fn_name
          def get_qualified_function_name(expr)
            node_index = get_state(:node_index)
            return expr.fn_name unless node_index
            
            entry = node_index[expr.object_id]
            return expr.fn_name unless entry && entry[:metadata]
            
            # Use qualified name from CallNameNormalizePass or effective name from CascadeDesugarPass
            entry[:metadata][:qualified_name] || entry[:metadata][:effective_fn_name] || expr.fn_name
          end


          # Trait-driven short-circuit lowering using the dedicated ShortCircuitLowerer
          def lower_short_circuit_bool(expr, ops, access_plans, scope_plan, need_indices, required_scope, cacheable)
            qualified_fn_name = get_qualified_function_name(expr)
            
            # Create lowerer lambda that captures the current context
            lowerer = lambda do |sub_expr, sub_ops, **opts|
              # Filter out unknown keywords for lower_expression
              valid_opts = opts.slice(:cacheable)
              lower_expression(sub_expr, sub_ops, access_plans, scope_plan, need_indices, required_scope, **valid_opts)
            end
            
            # Delegate to the dedicated lowering module
            short_circuit_lowerer.lower_expression!(
              expr: expr,
              ops: ops,
              lowerer: lowerer,
              qualified_fn_name: qualified_fn_name,
              cacheable: cacheable
            )
          end

        end
      end
    end
  end
end

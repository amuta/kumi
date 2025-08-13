# frozen_string_literal: true

module Kumi
  module Support
    # Pretty printer for IR modules - makes IR debugging much more readable
    module IRDump
      class << self
        def pretty_print(ir_module, show_inputs: true, analysis_state: nil)
          @analysis_state = analysis_state  # Store for use in other methods
          output = []
          
          if analysis_state
            output << "=" * 60
            output << "ANALYSIS STATE"
            output << "=" * 60
            output << format_analysis_state(analysis_state)
            output << ""
          end
          
          if show_inputs
            output << "=" * 60
            output << "INPUT METADATA"
            output << "=" * 60
            ir_module.inputs.each do |name, meta|
              output << format_input(name, meta)
            end
            output << ""
          end
          
          output << "=" * 60
          output << "IR DECLARATIONS (#{ir_module.decls.size})"
          output << "=" * 60
          
          ir_module.decls.each_with_index do |decl, decl_idx|
            output << ""
            output << format_declaration_header(decl, decl_idx)
            output << format_declaration_body(decl)
          end
          
          output.join("\n")
        end
        
        private
        
        def format_analysis_state(state)
          output = []
          
          # IR Lowering Overview
          output << "IR LOWERING STRATEGY:"
          output << "  • Plan selection: choose :read/:ravel/:each_indexed/:materialize per input path"
          output << "  • Shape tracking: Scalar vs Vec(scope, has_idx) for every slot"
          output << "  • Auto-alignment: AlignTo for elementwise maps across compatible scopes"
          output << "  • Twin generation: Vec declarations get __vec twin + Lift/Reduce for public access"
          output << "  • Reducers: aggregate functions (sum, max, etc.) use Reduce ops"
          output << "  • Cascades: compile to nested if/switch with lazy evaluation via guards"
          output << ""
          
          # Evaluation Order
          if state[:evaluation_order]
            order = state[:evaluation_order]
            output << "EVALUATION ORDER (#{order.size} declarations):"
            output << "  Topologically sorted: #{order.join(' → ')}"
            output << ""
          end
          
          # Access Plans
          if state[:access_plans]
            plans = state[:access_plans]
            total_plans = plans.values.map(&:size).sum
            output << "ACCESS PLANS (#{plans.size} input paths, #{total_plans} total plans):"
            output << "  Modes: :read (scalar), :ravel (flat vec), :each_indexed (indexed vec), :materialize (nested)"
            plans.each do |path, path_plans|
              output << "  #{path}:"
              path_plans.each do |plan|
                mode_info = case plan.mode
                           when :read then "scalar read (no traversal)"
                           when :ravel then "flattened vector (leaf values only)"
                           when :each_indexed then "indexed vector (with hierarchical indices)"
                           when :materialize then "structured data (preserves nesting)"
                           else plan.mode.to_s
                           end
                scope_info = plan.scope.empty? ? "" : " @#{plan.scope.join('.')}"
                output << "    #{plan.accessor_key} → #{mode_info}#{scope_info} (depth=#{plan.depth})"
              end
            end
            output << ""
          end
          
          # Join/Reduce Plans
          if state[:join_reduce_plans] && !state[:join_reduce_plans].empty?
            plans = state[:join_reduce_plans]
            output << "JOIN/REDUCE PLANS (#{plans.size} declarations):"
            plans.each do |name, plan|
              if plan.is_a?(Kumi::Core::Analyzer::Plans::Join)
                # Extract readable info from the Join struct
                policy = plan.policy
                target_scope = plan.target_scope
                
                parts = []
                parts << "policy=#{policy}"
                parts << "target_scope=#{target_scope}" unless target_scope.empty?
                
                output << "  #{name}: #{parts.join(', ')}"
                next
              elsif !plan.is_a?(Kumi::Core::Analyzer::Plans::Reduce)
                output << "  #{name}: (unknown plan type: #{plan.class})"
                next
              end
              
              # Extract readable info from the Reduce struct
              function = plan.function if
              axis = plan.axis
              source_scope = plan.source_scope
              result_scope = plan.result_scope
              flatten_args = plan.flatten_args
              
              parts = []
              parts << "function=#{function}"
              parts << "axis=#{axis}" 
              parts << "source_scope=#{source_scope}" 
              parts << "result_scope=#{result_scope}" 
              parts << "flatten_args=#{flatten_args}" 
              
              output << "  #{name}: #{parts.join(', ')}"
            end
            output << ""
          end
          
          # Scope Plans
          if state[:scope_plans] && !state[:scope_plans].empty?
            plans = state[:scope_plans]
            output << "SCOPE PLANS (#{plans.size} declarations):"
            plans.each do |name, plan|
              # Extract readable info from the Scope struct
              scope = plan.scope
              lifts = plan.lifts
              join_hint = plan.join_hint
              arg_shapes = plan.arg_shapes
              
              parts = []
              parts << "scope=#{scope}" 
              parts << "lifts=#{lifts}" 
              parts << "join_hint=#{join_hint}"
              parts << "arg_shapes=#{arg_shapes}" 
              
              if parts.empty?
                output << "  #{name}: (default scope)"
              else
                output << "  #{name}: #{parts.join(', ')}"
              end
            end
            output << ""
          end
          
          # Dependencies
          if state[:dependencies]
            deps = state[:dependencies]
            output << "DEPENDENCIES (#{deps.size} declarations):"
            deps.each do |name, dep_list|
              if dep_list.empty?
                output << "  #{name}: (no dependencies)"
              else
                # Extract readable info from dependency edges
                dep_info = dep_list.map do |dep|
                  if dep.respond_to?(:name) && dep.respond_to?(:kind)
                    "#{dep.name} (#{dep.kind})"
                  elsif dep.respond_to?(:name)
                    dep.name.to_s
                  elsif dep.respond_to?(:to_s)
                    dep.to_s.split('::').last || dep.to_s
                  else
                    dep.inspect
                  end
                end
                output << "  #{name}: depends on #{dep_info.join(', ')}"
              end
            end
            output << ""
          end
          
          # Type Information
          if state[:type_metadata]
            types = state[:type_metadata]
            output << "TYPE METADATA (#{types.size} declarations):"
            types.each do |name, type_info|
              type_str = case type_info
                        when Symbol then type_info.to_s
                        when Hash then type_info.inspect
                        else type_info.to_s
                        end
              output << "  #{name}: #{type_str}"
            end
            output << ""
          end
          
          # Functions Required
          if state[:functions_required]
            funcs = state[:functions_required]
            output << "FUNCTIONS REQUIRED (#{funcs.size} unique functions):"
            output << "  #{funcs.sort.join(', ')}"
            output << ""
          end
          
          # Declarations
          if state[:declarations]
            decls = state[:declarations]
            output << "DECLARATIONS (#{decls.size} total):"
            decls.each do |name, decl|
              kind = decl.is_a?(Kumi::Syntax::ValueDeclaration) ? "VALUE" : "TRAIT"
              expr_type = decl.expression.class.name.split('::').last
              output << "  #{name}: #{kind} (#{expr_type})"
            end
            output << ""
          end
          
          # Vector Twin Tracking (internal state)
          if state[:vec_meta]
            vec_meta = state[:vec_meta] || {}
            
            output << "VECTOR TWINS (internal tracking):"
            if vec_meta.empty?
              output << "  (no vector declarations)"
            else
              twin_names = vec_meta.keys.sort
              output << "  Twins created: #{twin_names.join(', ')}"
              vec_meta.each do |twin_name, meta|
                scope_info = meta[:scope].empty? ? "[]" : "[:#{meta[:scope].join(', :')}]"
                idx_info = meta[:has_idx] ? "indexed" : "ravel"
                output << "  #{twin_name}: vec[#{idx_info}]#{scope_info}"
              end
            end
            output << ""
          end
          
          # Analysis Errors (if any)
          if state[:errors] && !state[:errors].empty?
            errors = state[:errors]
            output << "ANALYSIS ERRORS (#{errors.size}):"
            errors.each_with_index do |error, idx|
              output << "  [#{idx + 1}] #{error}"
            end
            output << ""
          end
          
          output.join("\n")
        end
        
        def format_input(name, meta)
          type_info = meta[:type] ? " : #{meta[:type]}" : ""
          domain_info = meta[:domain] ? " ∈ #{meta[:domain]}" : ""
          "  #{name}#{type_info}#{domain_info}"
        end
        
        def format_declaration_header(decl, decl_idx)
          # Enhanced shape annotation with scope and type information
          vec_twin_name = :"#{decl.name}__vec"
          vec_meta = @analysis_state&.dig(:vec_meta)
          
          # Get type information from analysis state
          inferred_types = @analysis_state&.dig(:inferred_types) || {}
          inferred_type = inferred_types[decl.name]
          type_annotation = format_type_annotation(inferred_type, decl)
          
          if decl.shape == :vec && vec_meta && vec_meta[vec_twin_name]
            has_idx = vec_meta[vec_twin_name][:has_idx]
            scope = vec_meta[vec_twin_name][:scope] || []
            scope_str = scope.empty? ? "" : " by :#{scope.join(', :')}"
            
            if has_idx
              public_surface = "nested_arrays#{type_annotation}#{scope_str}"
              twin_annotation = "vec[indexed][:#{scope.join(', :')}]"
            else
              public_surface = "flat_array#{type_annotation}#{scope_str}"
              twin_annotation = "vec[ravel][:#{scope.join(', :')}]"
            end
            
            shape_info = " [public: #{public_surface}] (twin: #{twin_annotation})"
          elsif decl.shape == :vec
            public_surface = "vector#{type_annotation}"
            shape_info = " [public: #{public_surface}] (twin: vec[unknown])"
          else
            shape_info = " [public: scalar#{type_annotation}]"
          end
          
          kind_info = decl.kind.to_s.upcase
          
          # Count operation types for summary
          op_counts = decl.ops.group_by(&:tag).transform_values(&:size)
          op_summary = " (#{decl.ops.size} ops: #{op_counts.map { |k, v| "#{k}=#{v}" }.join(', ')})"
          
          "[#{decl_idx}] #{kind_info} #{decl.name}#{shape_info}#{op_summary}"
        end
        
        def format_declaration_body(decl)
          lines = []
          @decl_ops_context = decl.ops  # Store for broadcast detection
          
          decl.ops.each_with_index do |op, op_idx|
            lines << format_operation(op, op_idx)
          end
          
          lines.map { |line| "    #{line}" }
        end
        
        def format_operation(op, op_idx)
          case op.tag
          when :const
            value = op.attrs[:value]
            type_hint = case value
                       when String then " (str)"
                       when Integer then " (int)"
                       when Float then " (float)"
                       when TrueClass, FalseClass then " (bool)"
                       else ""
                       end
            "#{op_idx}: CONST #{value.inspect}#{type_hint} → s#{op_idx}"
            
          when :load_input
            plan_id = op.attrs[:plan_id]
            scope = op.attrs[:scope] || []
            is_scalar = op.attrs[:is_scalar]
            has_idx = op.attrs[:has_idx]
            
            # Parse plan_id to show what it's accessing
            path_info = plan_id.to_s.split(':')
            path = path_info[0]
            mode = path_info[1] || "read"
            
            if is_scalar
              shape_info = "scalar"
            else
              idx_info = has_idx ? "indexed" : "ravel"
              scope_info = scope.empty? ? "[]" : "[:#{scope.join(', :')}]"
              shape_info = "vec[#{idx_info}]#{scope_info}"
            end
            
            "#{op_idx}: #{path} → #{shape_info} → s#{op_idx}"
            
          when :ref
            name = op.attrs[:name]
            is_twin = name.to_s.end_with?("__vec")
            
            if is_twin
              # Look up scope information for twin
              vec_meta = @analysis_state&.dig(:vec_meta)
              if vec_meta && vec_meta[name]
                scope = vec_meta[name][:scope] || []
                has_idx = vec_meta[name][:has_idx]
                shape_info = has_idx ? "vec[indexed]" : "vec[ravel]"
                scope_info = scope.empty? ? "" : "[:#{scope.join(', :')}]"
                "#{op_idx}: REF #{name} → #{shape_info}#{scope_info} → s#{op_idx}"
              else
                "#{op_idx}: REF #{name} → vec[unknown] → s#{op_idx}"
              end
            else
              "#{op_idx}: REF #{name} → scalar → s#{op_idx}"
            end
            
          when :map
            fn_name = op.attrs[:fn]
            argc = op.attrs[:argc]
            args_str = op.args.map { |slot| "s#{slot}" }.join(", ")
            
            # Add function type information
            fn_type = case fn_name
                     when :multiply, :add, :subtract, :divide then " (math)"
                     when :>, :<, :>=, :<=, :==, :!= then " (comparison)"
                     when :and, :or, :not then " (logic)"
                     when :if then " (conditional)"
                     else ""
                     end
            
            # Check if this represents scalar-to-vector broadcast
            broadcast_note = ""
            if argc == 2 && op.args.size == 2
              # Look at the previous operations to see if we have scalar + vector
              # This is a heuristic - we'd need more context for perfect detection
              if @analysis_state
                # Try to detect scalar broadcast pattern: const followed by map
                prev_ops = @decl_ops_context
                if prev_ops && prev_ops[op.args[0]]&.tag == :const && prev_ops[op.args[1]]&.tag == :load_input
                  broadcast_note = " [scalar broadcast]"
                elsif prev_ops && prev_ops[op.args[1]]&.tag == :const && prev_ops[op.args[0]]&.tag == :load_input
                  broadcast_note = " [scalar broadcast]"
                end
              end
            end
            
            "#{op_idx}: MAP #{fn_name}#{fn_type}(#{args_str})#{broadcast_note} → s#{op_idx}"
            
          when :reduce
            fn_name = op.attrs[:fn]
            axis = op.attrs[:axis] || []
            result_scope = op.attrs[:result_scope] || []
            flatten_args = op.attrs[:flatten_args] || []
            args_str = op.args.map { |slot| "s#{slot}" }.join(", ")
            
            # Show grouping information with cleaner format
            if result_scope.empty?
              result_shape = "scalar"
            else
              result_shape = "grouped_vec[:#{result_scope.join(', :')}]"
            end
            
            axis_str = axis.empty? ? "" : " axis=[:#{axis.join(', :')}]"
            "#{op_idx}: REDUCE #{fn_name}(#{args_str})#{axis_str} → #{result_shape} → s#{op_idx}"
            
          when :array
            size = op.attrs[:size] || op.args.size
            args_str = op.args.map { |slot| "s#{slot}" }.join(", ")
            "#{op_idx}: ARRAY [#{args_str}] (#{size} elements) → s#{op_idx}"
            
          when :switch
            cases = op.attrs[:cases] || []
            default = op.attrs[:default]
            cases_str = cases.map { |(cond, val)| "s#{cond}→s#{val}" }.join(", ")
            default_str = default ? " else s#{default}" : ""
            "#{op_idx}: SWITCH {#{cases_str}#{default_str}} → s#{op_idx}"
            
          when :lift
            to_scope = op.attrs[:to_scope] || []
            args_str = op.args.map { |slot| "s#{slot}" }.join(", ")
            depth = to_scope.length
            scope_str = to_scope.empty? ? "" : " @:#{to_scope.join(', :')}"
            "#{op_idx}: LIFT #{args_str}#{scope_str} depth=#{depth} (→ nested_arrays[|#{to_scope.join('|')}|]) → s#{op_idx}"
            
          when :align_to
            to_scope = op.attrs[:to_scope] || []
            require_unique = op.attrs[:require_unique]
            on_missing = op.attrs[:on_missing]
            target_slot = op.args[0]
            source_slot = op.args[1]
            
            flags = []
            flags << "unique" if require_unique
            flags << "on_missing=#{on_missing}" if on_missing && on_missing != :error
            flag_str = flags.empty? ? "" : " (#{flags.join(', ')})"
            
            scope_str = to_scope.empty? ? "" : "[:#{to_scope.join(', :')}]"
            "#{op_idx}: ALIGN_TO target=s#{target_slot} source=s#{source_slot} to #{scope_str}#{flag_str} → s#{op_idx}"
            
          when :store
            name = op.attrs[:name]
            source_slot = op.args[0]
            is_twin = name.to_s.end_with?("__vec")
            store_type = is_twin ? " (vec twin)" : " (public)"
            "#{op_idx}: STORE #{name}#{store_type} ← s#{source_slot}"
            
          when :guard_push
            cond_slot = op.attrs[:cond_slot]
            "#{op_idx}: GUARD_PUSH s#{cond_slot} (enable if s#{cond_slot} is truthy)"
            
          when :guard_pop
            "#{op_idx}: GUARD_POP (restore previous guard state)"
            
          else
            # Fallback for unknown operations with enhanced information
            attrs_items = op.attrs.map { |k, v| "#{k}=#{v.inspect}" }
            attrs_str = attrs_items.empty? ? "" : " {#{attrs_items.join(', ')}}"
            args_str = op.args.empty? ? "" : " args=[#{op.args.join(', ')}]"
            "#{op_idx}: #{op.tag.to_s.upcase}#{attrs_str}#{args_str} → s#{op_idx}"
          end
        end
        
        def format_type_annotation(inferred_type, decl)
          return "" unless inferred_type
          
          case inferred_type
          when Symbol
            "(#{inferred_type.to_s.capitalize})"
          when Hash
            if inferred_type.key?(:array)
              element_type = inferred_type[:array]
              element_name = element_type.is_a?(Symbol) ? element_type.to_s.capitalize : element_type.to_s
              "(#{element_name})"
            else
              "(#{inferred_type.inspect})"
            end
          else
            # Fallback based on declaration type
            if decl.is_a?(Kumi::Syntax::TraitDeclaration)
              "(Boolean)"
            else
              "(#{inferred_type.class.name.split('::').last})"
            end
          end
        end
      end
    end
  end
end
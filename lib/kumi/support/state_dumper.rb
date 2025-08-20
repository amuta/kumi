# frozen_string_literal: true

module Kumi
  module Support
    module StateDumper
      module_function

      def dump_state(state, keys: nil, max_depth: 3)
        keys_to_dump = keys || state.keys
        keys_to_dump.each do |key|
          value = state[key]
          puts "=== #{key.to_s.upcase} ==="
          dump_value(value, depth: 0, max_depth: max_depth)
          puts
        end
      end

      def dump_value(value, depth: 0, max_depth: 3)
        indent = "  " * depth
        return puts "#{indent}[max depth reached]" if depth >= max_depth

        case value
        when Hash
          if value.empty?
            puts "#{indent}{}"
          else
            value.each { |k, v| puts "#{indent}#{k}:"; dump_value(v, depth: depth + 1, max_depth: max_depth) }
          end
        when Array
          if value.empty?
            puts "#{indent}[]"
          else
            value.each_with_index { |v, i| puts "#{indent}[#{i}]:"; dump_value(v, depth: depth + 1, max_depth: max_depth) }
          end
        when Struct
          puts "#{indent}#{value.class}"
          value.each_pair { |k, v| puts "#{indent}  #{k}: #{v.inspect}" }
        when Module, Class
          puts "#{indent}#{value}"
        else
          puts "#{indent}#{value.inspect}"
        end
      end

      def dump_node_index(state, filter: nil)
        node_index = state[:node_index] || {}
        puts "=== NODE_INDEX ==="
        node_index.each do |oid, metadata|
          next unless filter.nil? || filter.call(metadata)
          puts "OID #{oid}:"
          metadata.each { |key, value| puts "  #{key}: #{value.inspect}" }
          puts
        end
      end

      def dump_calls_only(state)
        dump_node_index(state) { |metadata| metadata[:expression_node]&.class&.name&.include?("CallExpression") }
      end

      # Dimensional debugging methods
      def dump_dimensional_summary(state)
        node_index = state[:node_index] || {}
        by_type = node_index.group_by { |_oid, meta| 
          node = meta[:expression_node] || meta[:node]
          node&.class&.name&.split("::")&.last || "Unknown" 
        }
        
        puts "=== DIMENSIONAL SUMMARY ==="
        by_type.each do |type, nodes|
          puts "\n#{type} (#{nodes.length} nodes):"
          nodes.each do |oid, metadata|
            node = metadata[:expression_node] || metadata[:node]
            scope = metadata[:inferred_scope]
            
            case type
            when /InputElementReference/
              path = node&.path&.join(".") || "unknown"
              puts "  OID #{oid}: #{path} → #{scope.inspect}"
            when /CallExpression/
              fn_name = node&.fn_name || "unknown"
              join_plan = metadata[:join_plan]
              if join_plan
                puts "  OID #{oid}: #{fn_name}() → target: #{join_plan[:target_scope]}, axis: #{join_plan[:axis]}"
              else
                puts "  OID #{oid}: #{fn_name}() → scope: #{scope.inspect}"
              end
            when /DeclarationReference/
              name = node&.name || "unknown"
              puts "  OID #{oid}: ref(#{name}) → scope: #{scope.inspect}"
            when /ValueDeclaration/
              name = node&.name || "unknown"
              puts "  OID #{oid}: decl(#{name}) → scope: #{scope.inspect}"
            else
              puts "  OID #{oid}: #{type} → scope: #{scope.inspect}"
            end
          end
        end
        puts
      end

      def dump_dimensional_issues(state)
        node_index = state[:node_index] || {}
        input_metadata = state[:input_metadata] || {}
        puts "=== DIMENSIONAL ISSUES ==="
        
        issues_found = false
        
        node_index.each do |oid, metadata|
          node = metadata[:expression_node] || metadata[:node]
          scope = metadata[:inferred_scope]
          next unless node && scope
          
          # Check InputElementReference scope consistency
          if node.class.name.include?("InputElementReference") && node.respond_to?(:path)
            expected_scope = compute_expected_scope_from_path(node.path, input_metadata)
            if scope != expected_scope
              puts "❌ OID #{oid}: Scope mismatch"
              puts "   Path: #{node.path.join('.')}"
              puts "   Expected: #{expected_scope.inspect}"
              puts "   Actual: #{scope.inspect}"
              issues_found = true
            end
          end
          
          # Check join plan consistency for reductions
          if metadata[:join_plan] && node.class.name.include?("CallExpression")
            join_plan = metadata[:join_plan]
            target_scope = join_plan[:target_scope]
            axis = join_plan[:axis]
            
            if join_plan[:policy] == :reduce && !axis.empty?
              arg_nodes = node.args.map { |arg| node_index[arg.object_id] }.compact
              source_scopes = arg_nodes.map { |meta| meta[:inferred_scope] }.compact.uniq
              
              if source_scopes.length == 1
                expected_target = source_scopes.first - axis
                if target_scope != expected_target
                  puts "❌ OID #{oid}: Join plan inconsistency"
                  puts "   Function: #{node.fn_name}"
                  puts "   Source scope: #{source_scopes.first.inspect}"
                  puts "   Axis: #{axis.inspect}"
                  puts "   Expected target: #{expected_target.inspect}"
                  puts "   Actual target: #{target_scope.inspect}"
                  issues_found = true
                end
              end
            end
          end
        end
        
        puts "✅ No dimensional issues found" unless issues_found
        puts
      end

      def dump_compact_summary(state)
        node_index = state[:node_index] || {}
        by_type = node_index.group_by { |_oid, meta| 
          node = meta[:expression_node] || meta[:node]
          node&.class&.name&.split("::")&.last || "Unknown" 
        }
        
        puts "=== COMPACT SUMMARY ==="
        by_type.each do |type, nodes|
          scoped_count = nodes.count { |_oid, meta| meta[:inferred_scope] && !meta[:inferred_scope].empty? }
          join_plan_count = nodes.count { |_oid, meta| meta[:join_plan] }
          puts "#{type}: #{nodes.length} nodes (#{scoped_count} scoped, #{join_plan_count} join plans)"
        end
        puts
      end

      def dump_issue_summary(state)
        node_index = state[:node_index] || {}
        input_metadata = state[:input_metadata] || {}
        issues = []
        
        node_index.each do |oid, metadata|
          node = metadata[:expression_node] || metadata[:node]
          next unless node
          
          if node.class.name.include?("InputElementReference") && node.respond_to?(:path)
            expected = compute_expected_scope_from_path(node.path, input_metadata)
            actual = metadata[:inferred_scope]
            if expected != actual
              issues << "OID #{oid}: scope mismatch (#{node.path.join('.')})"
            end
          end
          
          if metadata[:join_plan] && node.class.name.include?("CallExpression")
            plan = metadata[:join_plan]
            if plan[:policy] == :reduce && plan[:target_scope]&.any? { |dim| dim.to_s.include?("info") }
              issues << "OID #{oid}: hash in target_scope (#{node.fn_name})"
            end
          end
        end
        
        puts "=== ISSUE SUMMARY ==="
        if issues.empty?
          puts "✅ No issues detected"
        else
          issues.each { |issue| puts "❌ #{issue}" }
        end
        puts
      end

      def find_problematic_nodes(state)
        node_index = state[:node_index] || {}
        input_metadata = state[:input_metadata] || {}
        problems = {}
        
        node_index.each do |oid, metadata|
          node = metadata[:expression_node] || metadata[:node]
          next unless node
          
          if node.class.name.include?("InputElementReference")
            expected = compute_expected_scope_from_path(node.path, input_metadata)
            actual = metadata[:inferred_scope]
            if expected != actual
              problems[oid] = { type: :scope_mismatch, node: node, expected: expected, actual: actual }
            end
          end
          
          if metadata[:join_plan]&.dig(:target_scope)&.any? { |dim| dim.to_s.include?("info") }
            problems[oid] = { type: :hash_contamination, node: node, target_scope: metadata[:join_plan][:target_scope] }
          end
        end
        
        puts "=== PROBLEMATIC NODES ==="
        if problems.empty?
          puts "✅ No problematic nodes found"
        else
          problems.each do |oid, info|
            case info[:type]
            when :scope_mismatch
              puts "❌ OID #{oid}: Expected #{info[:expected]}, got #{info[:actual]}"
            when :hash_contamination
              puts "❌ OID #{oid}: Hash contamination in #{info[:target_scope]}"
            end
          end
        end
        puts
        problems
      end

      def dump_dimensional_trace(state, target_oid)
        node_index = state[:node_index] || {}
        target_meta = node_index[target_oid]
        return unless target_meta
        
        puts "=== DIMENSIONAL TRACE FOR OID #{target_oid} ==="
        node = target_meta[:expression_node] || target_meta[:node]
        puts "Node: #{describe_node(node)}"
        puts "Scope: #{target_meta[:inferred_scope].inspect}"
        
        if target_meta[:join_plan]
          plan = target_meta[:join_plan]
          puts "Join Plan:"
          puts "  Policy: #{plan[:policy]}"
          puts "  Target: #{plan[:target_scope]}"
          puts "  Axis: #{plan[:axis]}"
        end
        
        if node&.respond_to?(:args)
          puts "\nDependencies:"
          node.args.each_with_index do |arg, i|
            arg_meta = node_index[arg.object_id]
            if arg_meta
              puts "  Arg #{i}: #{describe_node(arg)} → #{arg_meta[:inferred_scope].inspect}"
            end
          end
        end
        puts
      end

      def find_nodes_by_path(state, path_pattern)
        node_index = state[:node_index] || {}
        matches = node_index.select do |_oid, metadata|
          node = metadata[:expression_node] || metadata[:node]
          node&.respond_to?(:path) && node.path&.join('.')&.include?(path_pattern.to_s)
        end
        
        puts "=== NODES MATCHING PATH: #{path_pattern} ==="
        if matches.empty?
          puts "No matches found"
        else
          matches.each do |oid, metadata|
            node = metadata[:expression_node] || metadata[:node]
            scope = metadata[:inferred_scope]
            path_str = node&.path&.join('.') || 'unknown'
            puts "OID #{oid}: #{path_str} → #{scope.inspect}"
          end
        end
        puts
        matches
      end

      def find_nodes_by_function(state, fn_name)
        node_index = state[:node_index] || {}
        matches = node_index.select do |_oid, metadata|
          node = metadata[:expression_node] || metadata[:node]
          node&.respond_to?(:fn_name) && (node.fn_name == fn_name || node.fn_name.to_s.include?(fn_name.to_s))
        end
        
        puts "=== NODES MATCHING FUNCTION: #{fn_name} ==="
        if matches.empty?
          puts "No matches found"
        else
          matches.each do |oid, metadata|
            node = metadata[:expression_node] || metadata[:node]
            scope = metadata[:inferred_scope]
            join_plan = metadata[:join_plan]
            fn_name_str = node&.fn_name || 'unknown'
            puts "OID #{oid}: #{fn_name_str}() → scope: #{scope.inspect}"
            puts "  join_plan: #{join_plan.inspect}" if join_plan
          end
        end
        puts
        matches
      end

      def compare_states(state1, state2, focus: :dimensional)
        puts "=== STATE COMPARISON ==="
        if focus == :dimensional
          compare_dimensional_metadata(state1, state2)
        else
          compare_full_states(state1, state2)
        end
      end

      def dump_complete_diagnostic(state)
        puts "=" * 60
        puts "=== COMPLETE DIMENSIONAL DIAGNOSTIC ==="
        puts "=" * 60
        
        dump_compact_summary(state)
        dump_issue_summary(state)
        problems = find_problematic_nodes(state)
        
        if problems.empty?
          dump_dimensional_summary(state)
          dump_reference_graph(state)
        else
          puts "🚨 ISSUE ANALYSIS:"
          problems.each { |oid, _info| dump_dimensional_trace(state, oid) }
        end
        
        puts "=" * 60
        puts "=== DIAGNOSTIC COMPLETE ==="
        puts "=" * 60
      end

      # Reference analysis
      def dump_node_relationships(state)
        node_index = state[:node_index] || {}
        puts "=== NODE RELATIONSHIPS ==="
        references = build_reference_map(node_index)
        
        references.each do |oid, info|
          metadata = node_index[oid]
          scope = metadata&.dig(:inferred_scope) || []
          puts "OID #{oid} (#{info[:type]}): #{info[:name]} → #{scope.inspect}"
          
          info[:references].each do |ref_oid|
            ref_meta = node_index[ref_oid]
            if ref_meta
              ref_node = ref_meta[:expression_node] || ref_meta[:node]
              ref_scope = ref_meta[:inferred_scope] || []
              ref_desc = describe_node(ref_node)
              puts "  → OID #{ref_oid}: #{ref_desc} → #{ref_scope.inspect}"
            else
              puts "  → OID #{ref_oid}: [missing metadata]"
            end
          end
          puts
        end
      end

      def dump_dependency_chain(state, start_oid)
        node_index = state[:node_index] || {}
        visited = Set.new
        puts "=== DEPENDENCY CHAIN FROM OID #{start_oid} ==="
        trace_dependencies(start_oid, node_index, visited, 0)
        puts
      end

      def dump_reference_graph(state)
        node_index = state[:node_index] || {}
        puts "=== REFERENCE GRAPH ==="
        references = build_reference_map(node_index)
        by_type = references.group_by { |_oid, info| info[:type] }
        
        by_type.each do |type, nodes|
          puts "\n#{type.to_s.upcase}:"
          nodes.each do |oid, info|
            metadata = node_index[oid]
            scope = metadata&.dig(:inferred_scope) || []
            scope_str = scope.empty? ? "[]" : scope.inspect
            
            puts "  #{info[:name]} (#{oid}) #{scope_str}"
            if info[:references].any?
              puts "    ├─ references: #{info[:references].length} nodes"
              info[:references].each_with_index do |ref_oid, i|
                is_last = i == info[:references].length - 1
                prefix = is_last ? "    └─" : "    ├─"
                ref_meta = node_index[ref_oid]
                if ref_meta
                  ref_node = ref_meta[:expression_node] || ref_meta[:node]
                  ref_desc = describe_node(ref_node)
                  ref_scope = ref_meta[:inferred_scope] || []
                  puts "#{prefix} #{ref_desc} → #{ref_scope.inspect}"
                end
              end
            end
          end
        end
        puts
      end

      # Helper methods
      def build_reference_map(node_index)
        references = {}
        node_index.each do |oid, metadata|
          node = metadata[:expression_node] || metadata[:node]
          next unless node
          
          case node.class.name
          when /CallExpression/
            references[oid] = { type: :call, name: node.fn_name, references: node.args&.map(&:object_id) || [] }
          when /DeclarationReference/
            references[oid] = { type: :declaration_ref, name: node.name, references: [] }
          when /ValueDeclaration/
            references[oid] = { type: :value_decl, name: node.name, references: [node.expression&.object_id].compact }
          when /InputElementReference/
            references[oid] = { type: :input_ref, name: node.path&.join('.') || 'unknown', references: [] }
          end
        end
        references
      end

      def trace_dependencies(oid, node_index, visited, depth)
        return if visited.include?(oid) || depth > 5
        visited.add(oid)
        
        metadata = node_index[oid]
        return unless metadata
        
        node = metadata[:expression_node] || metadata[:node]
        indent = "  " * depth
        scope = metadata[:inferred_scope] || []
        puts "#{indent}#{describe_node(node)} → #{scope.inspect}"
        
        if node&.respond_to?(:args)
          node.args&.each { |arg| trace_dependencies(arg.object_id, node_index, visited, depth + 1) }
        elsif node&.respond_to?(:expression)
          trace_dependencies(node.expression&.object_id, node_index, visited, depth + 1)
        end
      end

      def compute_expected_scope_from_path(path, input_metadata)
        return [] if path.empty?
        
        scope = []
        current = input_metadata
        
        path[0...-1].each do |segment|
          field = current[segment]
          return scope unless field
          scope << segment if field.type == :array
          current = field.children || {}
        end
        scope
      end

      def compare_dimensional_metadata(state1, state2)
        node_index1 = state1[:node_index] || {}
        node_index2 = state2[:node_index] || {}
        common_oids = node_index1.keys & node_index2.keys
        changes_found = false
        
        common_oids.each do |oid|
          meta1 = node_index1[oid]
          meta2 = node_index2[oid]
          
          scope1 = meta1[:inferred_scope]
          scope2 = meta2[:inferred_scope]
          
          if scope1 != scope2
            node = meta1[:expression_node] || meta2[:expression_node]
            node_desc = describe_node(node)
            puts "🔄 OID #{oid} (#{node_desc}): scope changed"
            puts "   Before: #{scope1.inspect}"
            puts "   After:  #{scope2.inspect}"
            changes_found = true
          end
          
          plan1 = meta1[:join_plan]
          plan2 = meta2[:join_plan]
          
          if plan1 != plan2
            node = meta1[:expression_node] || meta2[:expression_node]
            node_desc = describe_node(node)
            puts "🔄 OID #{oid} (#{node_desc}): join_plan changed"
            puts "   Before: #{plan1.inspect}"
            puts "   After:  #{plan2.inspect}"
            changes_found = true
          end
        end
        
        puts "✅ No dimensional changes detected" unless changes_found
      end

      def compare_full_states(state1, state2)
        keys1 = state1.keys.to_set
        keys2 = state2.keys.to_set
        
        added_keys = keys2 - keys1
        removed_keys = keys1 - keys2
        common_keys = keys1 & keys2
        
        puts "Added keys: #{added_keys.to_a}" unless added_keys.empty?
        puts "Removed keys: #{removed_keys.to_a}" unless removed_keys.empty?
        common_keys.each { |key| puts "Changed: #{key}" if state1[key] != state2[key] }
      end

      def describe_node(node)
        return "Unknown" unless node
        
        case node.class.name
        when /InputElementReference/
          "input:#{node.path&.join('.')}"
        when /CallExpression/
          "call:#{node.fn_name}"
        when /DeclarationReference/
          "ref:#{node.name}"
        when /ValueDeclaration/
          "decl:#{node.name}"
        else
          node.class.name
        end
      end
    end
  end
end
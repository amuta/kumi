# frozen_string_literal: true

require "set"

module Kumi
  module Core
    module IRV2
      class Value
        attr_reader :id, :op, :args, :attrs
        
        def initialize(id, op, args, attrs)
          @id, @op, @args, @attrs = id, op, args, attrs
        end
        
        def to_s
          a = args.map { |x| x.is_a?(Value) ? "%#{x.id}" : x.inspect }.join(", ")
          attrs_s = attrs.empty? ? "" : " " + attrs.map { |k,v| "#{k}: #{v.inspect}" }.join(", ")
          "%%%d = %s(%s)%s" % [id, op, a, attrs_s]
        end
      end

      class Builder
        attr_reader :values, :stores
        
        def initialize
          @next_id = 0
          @values  = []
          @stores  = []
        end

        def load_input(path)                 = emit(:LoadInput, [path], {})
        def load_param(name)                 = emit(:LoadParam, [name], {})
        def load_decl(name)                  = emit(:LoadDecl, [name], {})
        def const(lit)                       = emit(:Const, [lit], {})
        def align_to(v, axes_tokens)         = emit(:AlignTo, [v], {axes: axes_tokens})
        def map(kernel, *vs)                 = emit(:Map, vs, {op: kernel})
        def reduce(kernel, v, last_axis)     = emit(:Reduce, [v], {op: kernel, last_axis: last_axis})
        def construct_tuple(*vs)             = emit(:ConstructTuple, vs, {})
        def tuple_get(v, index)              = emit(:TupleGet, [v], {index: index})
        def store(name, v)                   = (@stores << [name, v]; nil)

        def dump
          ([*values.map(&:to_s), *stores.map { |(n,v)| "Store #{n}, %#{v.id}" }]).join("\n")
        end

        private
        
        def emit(op, args, attrs)
          v = Value.new(@next_id, op, args, attrs)
          @values << v
          @next_id += 1
          v
        end
      end

      class Declaration
        attr_reader :name, :operations, :result, :parameters
        
        def initialize(name, operations, result, parameters = [])
          @name = name
          @operations = operations
          @result = result
          @parameters = parameters
        end
        
        def inputs
          @parameters.select { |p| p[:type] == :input }
        end
        
        def dependencies
          @parameters.select { |p| p[:type] == :dependency }.map { |p| p[:source] }
        end
      end

      class Module
        attr_reader :values, :stores, :metadata, :declarations
        
        def initialize(values = nil, stores = nil, metadata = {}, declarations = nil)
          # Support both old and new format
          if declarations
            @declarations = declarations
            @values = nil
            @stores = nil
          else
            @values = values
            @stores = stores
          end
          @metadata = metadata
        end
        
        def to_s
          if @declarations
            format_declaration_based
          else
            format_legacy
          end
        end

        private

        def format_declaration_based
          output = []
          output << "; — Module: Declaration-Based IR"
          output << ""
          
          @declarations.each do |name, decl|
            output << "Declaration #{name} {"
            
            unless decl.parameters.empty?
              output << "  params:"
              decl.parameters.each do |param|
                case param[:type]
                when :input
                  output << "    #{param[:name]} : View(#{param[:dtype]}, axes=#{param[:axes]})"
                when :dependency
                  output << "    #{param[:name]} : View(#{param[:dtype]}, axes=#{param[:axes]})  ; #{param[:source]}"
                end
              end
            end
            
            output << "  operations: ["
            decl.operations.each do |op|
              comment = format_operation_comment(op)
              op_str = format_operation(op)
              padding = [50 - op_str.length, 1].max
              output << "    #{op_str}#{' ' * padding}; #{comment}"
            end
            output << "  ]"
            output << "  result: %#{decl.result.id}"
            output << "}"
            output << ""
          end
          
          output.join("\n")
        end

        def format_legacy
          output = []
          
          # Group and display inputs
          inputs = collect_inputs
          unless inputs.empty?
            output << "; — inputs"
            inputs.each do |path, (value, scope, dtype)|
              scope_str = scope.empty? ? "[]" : "[#{scope.map(&:inspect).join(',')}]"
              output << "%#{value.id} = LoadInput #{path.inspect}#{' ' * [40 - "LoadInput #{path.inspect}".length, 1].max}; #{scope_str}, #{dtype}"
            end
            output << ""
          end
          
          # Track globally shown operations to avoid duplication
          global_shown = Set.new
          
          # Group operations by store
          stores.each do |name, store_value|
            related_ops = collect_related_operations(store_value)
            
            # Filter out operations we've already shown
            new_ops = related_ops.reject do |val|
              val.op == :LoadInput || global_shown.include?(val.id)
            end
            
            # Add declaration comment
            output << "; #{name}"
            
            # Show new operations leading to this store
            new_ops.each do |val|
              comment = format_operation_comment(val)
              op_str = format_operation(val)
              padding = [60 - op_str.length, 1].max
              output << "#{op_str}#{' ' * padding}; #{comment}"
              global_shown.add(val.id)
            end
            
            output << "Store #{name}, %#{store_value.id}"
            output << ""
          end
          
          output.join("\n")
        end
        
        private
        
        def collect_inputs
          inputs = {}
          # Collect all LoadInput operations, but only keep the first one for each path
          values.each do |val|
            if val.op == :LoadInput
              path = val.args.first
              next if inputs.key?(path) # Skip duplicates, keep first occurrence
              
              # Extract scope and dtype from metadata if available
              scope = metadata.dig(:input_scopes, path) || extract_scope_from_path(path)
              dtype = metadata.dig(:input_types, path) || :unknown
              inputs[path] = [val, scope, dtype]
            end
          end
          inputs.sort_by { |path, (val, _, _)| val.id } # Sort by ID for consistent output
        end
        
        def collect_related_operations(target_value)
          visited = Set.new
          operations = []
          
          def traverse_dependencies(val, visited, operations)
            return if visited.include?(val.id)
            visited.add(val.id)
            
            # Add dependencies first (topological order)
            val.args.each do |arg|
              traverse_dependencies(arg, visited, operations) if arg.is_a?(Value)
            end
            
            operations << val
          end
          
          traverse_dependencies(target_value, visited, operations)
          operations
        end
        
        def extract_scope_from_path(path)
          # Extract scope from path - everything except the last element
          path.length > 1 ? path[0..-2] : []
        end
        
        def format_operation(val)
          case val.op
          when :LoadInput
            "%#{val.id} = LoadInput #{val.args.first.inspect}"
          when :LoadParam
            "%#{val.id} = LoadParam #{val.args.first.inspect}"
          when :LoadDecl
            "%#{val.id} = LoadDecl #{val.args.first.inspect}"
          when :Map
            args_str = val.args.map { |a| "%#{a.id}" }.join(", ")
            op_name = val.attrs[:op] || "unknown"
            "%#{val.id} = Map(#{op_name}, #{args_str})"
          when :Reduce
            op_name = val.attrs[:op] || "unknown" 
            last_axis = val.attrs[:last_axis]
            "%#{val.id} = Reduce(#{op_name}, %#{val.args.first.id}, #{last_axis.inspect})"
          when :AlignTo
            axes_str = val.attrs[:axes].map(&:inspect).join(",")
            "%#{val.id} = AlignTo(%#{val.args.first.id}, [#{axes_str}])"
          when :ConstructTuple
            args_str = val.args.map { |a| "%#{a.id}" }.join(", ")
            "%#{val.id} = ConstructTuple(#{args_str})"
          else
            val.to_s
          end
        end
        
        def format_operation_comment(val)
          # Extract dimensional information from metadata if available
          scope = metadata.dig(:operation_scopes, val.id) || []
          dtype = metadata.dig(:operation_types, val.id) || :unknown
          
          scope_str = scope.empty? ? "[]" : "[#{scope.map(&:inspect).join(',')}]"
          "#{scope_str}, #{dtype}"
        end
      end
    end
  end
end
# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY:
        #   - Resolve ambiguous functions using complete type information
        #   - Run after TypeChecker when all types are inferred
        #
        # DEPENDS ON:
        #   - CallNameNormalizePass (sets :ambiguous_function metadata)
        #   - TypeCheckerV2 (provides complete :inferred_types)
        #
        # PRODUCES:
        #   - Updated :node_index with resolved qualified_name and fn_class for ambiguous functions
        #
        class AmbiguityResolverPass < PassBase
          def run(errors)
            node_index = get_state(:node_index)
            @input_meta = get_state(:input_metadata)
            @input_index = get_state(:input_index)
            inferred_types = get_state(:inferred_types)

            # Create updated node_index with resolved ambiguous functions
            updated_node_index = node_index.dup

            node_index.each do |object_id, entry|
              next unless entry[:type] == "CallExpression"
              next unless entry[:metadata][:ambiguous_candidates]

              resolution = resolve_ambiguous_function(entry, inferred_types, errors)
              next unless resolution

              # Update the metadata with resolved information
              updated_entry = entry.dup
              updated_metadata = entry[:metadata].dup
              updated_metadata[:qualified_name] = resolution[:qualified_name]
              updated_metadata[:fn_class] = resolution[:fn_class]
              updated_metadata.delete(:ambiguous_candidates)

              # Attach signature metadata if available
              if resolution[:signature_plan]
                plan = resolution[:signature_plan]
                updated_metadata[:selected_signature] = plan[:signature]
                updated_metadata[:result_axes] = plan[:result_axes]
                updated_metadata[:join_policy] = plan[:join_policy]
                updated_metadata[:dropped_axes] = plan[:dropped_axes]
                updated_metadata[:effective_signature] = plan[:effective_signature]
                updated_metadata[:dim_env] = plan[:env]
                updated_metadata[:signature_score] = plan[:score]
              end

              updated_entry[:metadata] = updated_metadata
              updated_node_index[object_id] = updated_entry
            end

            # Return new state with updated node_index
            state.with(:node_index, updated_node_index)
          end

          private

          def resolve_ambiguous_function(entry, inferred_types, errors)
            node = entry[:node]
            candidates = entry[:metadata][:ambiguous_candidates]

            if ENV["DEBUG_AMBIGUITY"]
              puts "AmbiguityResolver: Resolving #{node.fn_name} with candidates: #{candidates.map(&:name)}"
              puts "  Available metadata keys: #{entry[:metadata].keys.inspect}"
            end

            # Use proper metadata instead of guessing types
            resolved_function = resolve_using_rich_metadata(node, candidates, entry[:metadata], inferred_types)

            if resolved_function
              puts "  Resolved to: #{resolved_function[:qualified_name]} using rich metadata" if ENV["DEBUG_AMBIGUITY"]

              resolved_function
            else
              # Still ambiguous after metadata-based resolution
              error_msg = "ambiguous function #{node.fn_name} (candidates: #{candidates.map(&:name).join(', ')}); use a qualified name or provide type hints"
              report_error(errors, error_msg, location: node.loc, type: :type)
              nil
            end
          end

          def resolve_using_rich_metadata(node, candidates, metadata, inferred_types)
            # Try signature-based resolution first (most robust)
            if result = try_signature_based_resolution(node, candidates, metadata)
              return {
                qualified_name: result[:candidate].name,
                fn_class: result[:candidate].class_sym,
                signature_plan: result[:plan]
              }
            end

            # Fallback to type-based resolution for simpler cases
            if metadata[:inferred_arg_types]
              puts "  Using inferred_arg_types from TypeInferencerPass: #{metadata[:inferred_arg_types].inspect}" if ENV["DEBUG_AMBIGUITY"]

              return find_candidate_by_argument_types(candidates, metadata[:inferred_arg_types])
            end

            # Final fallback: Build argument types directly if not available in metadata
            arg_types = build_rich_argument_types(node, inferred_types)
            puts "  Fallback: Building argument types directly: #{arg_types.inspect}" if ENV["DEBUG_AMBIGUITY"]

            find_candidate_by_argument_types(candidates, arg_types)
          end

          def try_signature_based_resolution(node, candidates, metadata)
            # Use SignatureResolver.choose() to pick the best candidate based on signatures
            # This leverages the same logic as FunctionSignaturePass but for ambiguous functions

            puts "  Trying signature-based resolution with #{candidates.length} candidates" if ENV["DEBUG_AMBIGUITY"]

            # Build argument shapes from node structure and broadcast metadata
            arg_shapes = build_argument_shapes_for_node(node)
            puts "  Built argument shapes: #{arg_shapes.inspect}" if ENV["DEBUG_AMBIGUITY"]

            # Try each candidate and see which ones have valid signature matches
            valid_candidates = []

            candidates.each do |candidate|
              # Get signatures for this candidate
              signatures_raw = registry_v2.get_function_signatures(candidate.name)
              signatures = parse_signatures(signatures_raw)

              puts "  Candidate #{candidate.name}: #{signatures.length} signatures" if ENV["DEBUG_AMBIGUITY"]

              # Try signature resolution for this candidate
              plan = Kumi::Core::Functions::SignatureResolver.choose(
                signatures: signatures,
                arg_shapes: arg_shapes
              )

              valid_candidates << { candidate: candidate, plan: plan }
              puts "    ✓ Valid match with score #{plan[:score]}" if ENV["DEBUG_AMBIGUITY"]
            rescue Kumi::Core::Functions::SignatureMatchError => e
              puts "    ✗ No valid signature match: #{e.message}" if ENV["DEBUG_AMBIGUITY"]
              # This candidate doesn't match, continue
            rescue StandardError => e
              puts "    ✗ Error checking candidate: #{e.message}" if ENV["DEBUG_AMBIGUITY"]
            end

            # If exactly one candidate has valid signatures, choose it
            if valid_candidates.length == 1
              winner = valid_candidates.first
              puts "  Resolved to: #{winner[:candidate].name} (only valid candidate)" if ENV["DEBUG_AMBIGUITY"]
              return { candidate: winner[:candidate], plan: winner[:plan] }
            end

            # If multiple candidates are valid, choose the one with the best score
            if valid_candidates.length > 1
              best = valid_candidates.max_by { |vc| vc[:plan][:score] }
              puts "  Resolved to: #{best[:candidate].name} (best score: #{best[:plan][:score]})" if ENV["DEBUG_AMBIGUITY"]
              return { candidate: best[:candidate], plan: best[:plan] }
            end

            # No valid candidates found
            puts "  No candidates had valid signatures" if ENV["DEBUG_AMBIGUITY"]
            nil
          end

          def find_candidate_by_argument_types(candidates, arg_types)
            return nil if arg_types.empty?

            first_arg_type = arg_types.first

            # Handle array types (can be symbol or hash format)
            if first_arg_type == :array || (first_arg_type.is_a?(Hash) && first_arg_type.key?(:array))
              array_candidate = candidates.find { |c| c.name.start_with?("array.") }
              return array_candidate if array_candidate
            end

            # Handle string types
            if first_arg_type == :string
              string_candidate = candidates.find { |c| c.name.start_with?("string.") }
              return string_candidate if string_candidate
            end

            # Handle struct/object types (fallback for non-array, non-string)
            if %i[hash object any].include?(first_arg_type)
              struct_candidate = candidates.find { |c| c.name.start_with?("struct.") }
              return struct_candidate if struct_candidate
            end

            # If no clear match, return nil to trigger error
            nil
          end

          def build_argument_shapes_for_node(node)
            # Use DimTracer for accurate dimensional analysis
            node.args.map { |arg| Kumi::Core::Analyzer::DimTracer.trace(arg, @input_metadata, @input_index)[:dims] }
          end

          def parse_signatures(sig_strings)
            # Reuse signature parsing logic from FunctionSignaturePass
            @sig_cache ||= {}
            sig_strings.map do |s|
              @sig_cache[s] ||= Kumi::Core::Functions::SignatureParser.parse(s)
            end
          end

          def build_rich_argument_types(node, inferred_types)
            node.args.map do |arg|
              case arg
              when Kumi::Syntax::InputReference, Kumi::Syntax::InputElementReference
                get_type_for_input_reference(arg)
              when Kumi::Syntax::DeclarationReference
                inferred_types[arg.name] || :any
              when Kumi::Syntax::Literal
                infer_literal_type(arg.value)
              else
                :any
              end
            end
          end

          def build_argument_types_for_node(node, inferred_types)
            if ENV["DEBUG_AMBIGUITY"]
              puts "  Building arg types for #{node.fn_name}:"
              puts "    inferred_types keys: #{inferred_types.keys.inspect}"
              puts "    args: #{node.args.map do |a|
                "#{a.class.name.split('::').last}(#{a.respond_to?(:name) ? a.name : a.inspect[0, 20]})"
              end}"
            end

            node.args.map do |arg|
              case arg
              when Kumi::Syntax::InputReference, Kumi::Syntax::InputElementReference
                # Get type from input metadata or element types
                get_type_for_input_reference(arg)
              when Kumi::Syntax::DeclarationReference
                # Get type from inferred types
                inferred_type = inferred_types[arg.name] || :any
                puts "    DeclarationReference #{arg.name}: #{inferred_type}" if ENV["DEBUG_AMBIGUITY"]
                inferred_type
              when Kumi::Syntax::Literal
                # Infer type from literal value
                literal_type = infer_literal_type(arg.value)
                puts "    Literal #{arg.value.inspect}: #{literal_type}" if ENV["DEBUG_AMBIGUITY"]
                literal_type
              else
                puts "    Unknown arg type #{arg.class}: :any" if ENV["DEBUG_AMBIGUITY"]
                :any
              end
            end
          end

          def get_type_for_input_reference(ref)
            input_metadata = get_state(:input_metadata, required: true)
            if ref.is_a?(Kumi::Syntax::InputElementReference)
              # For array element access like input.items.name, path is [:items, :name]
              path = ref.path
              return :any unless path.length >= 2

              input_name = path[0]
              field_name = path[1]

              base_field = input_metadata[input_name]
              return :any unless base_field && base_field.type == :array

              children = base_field.children
              return :any unless children && children[field_name]

              children[field_name].type || :any
            else
              # For direct input reference like input.name
              field_name = ref.respond_to?(:field_name) ? ref.field_name : ref.path&.first
              field = input_metadata[field_name]
              field ? (field.type || :any) : :any
            end
          end

          def infer_literal_type(value)
            case value
            when String then :string
            when Integer then :integer
            when Float then :float
            when TrueClass, FalseClass then :boolean
            else :any
            end
          end
        end
      end
    end
  end
end

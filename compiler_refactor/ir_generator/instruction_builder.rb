# frozen_string_literal: true

module Kumi
  module Core
    module IRGeneratorModules
      # Handles the main instruction generation flow
      module InstructionBuilder
        private

        def generate_instructions
          instructions = []
          
          # Process declarations in topological order
          @analysis.topo_order.each do |name|
            declaration = find_declaration(name)
            next unless declaration
            
            # Generate temp instructions first (from TAC decomposition)
            temp_instructions = flush_temp_instructions
            instructions.concat(temp_instructions)
            
            # Then generate the main instruction
            instruction = generate_instruction(declaration)
            instructions << instruction if instruction
          end
          
          instructions
        end

        def find_declaration(name)
          # Get declarations from the AST
          (@syntax_tree.attributes + @syntax_tree.traits).find { |decl| decl.name == name }
        end

        def generate_instruction(declaration)
          # Determine operation type from broadcast detector metadata
          detector_metadata = @state[:detector_metadata] || {}
          decl_meta = detector_metadata[declaration.name] || {}
          operation_type = decl_meta[:operation_type] || :scalar
          
          # Get base type from inferencer and coordinate with broadcast detector
          base_type = @analysis.decl_types[declaration.name]
          data_type = coordinate_type(base_type, operation_type, decl_meta)
          
          {
            name: declaration.name,
            type: declaration.class.name.split('::').last.downcase.to_sym, # :value_declaration or :trait_declaration
            operation_type: operation_type,
            data_type: data_type,
            compilation: generate_compilation_info(declaration.expression, operation_type, decl_meta)
          }
        end
      end
    end
  end
end
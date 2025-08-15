# frozen_string_literal: true

module Kumi
  module Core
    module IR
      # Extract function names used in IR modules for building minimal function registries
      class FunctionExtractor
        def self.extract_function_names(ir_module)
          function_names = Set.new
          
          ir_module.decls.each do |decl|
            decl.ops.each do |op|
              case op.tag
              when :map, :reduce
                fn_name = op.attrs[:fn]
                # Convert symbols to qualified names for core functions
                fn_name = case fn_name
                         when :not then "core.not"
                         when :and then "core.and" 
                         when :or then "core.or"
                         when :if then "core.if"
                         when "not" then "core.not"  # Handle string versions too
                         when "and" then "core.and"
                         when "or" then "core.or"
                         when "if" then "core.if"
                         else fn_name
                         end
                function_names << fn_name
              end
            end
          end
          
          function_names.to_a
        end
        
        # Build function hash from RegistryV2 for only the needed functions
        def self.build_function_hash(ir_module)
          needed_functions = extract_function_names(ir_module)
          registry_v2 = Kumi::Core::Functions::RegistryV2.load_from_file
          
          if ENV["DEBUG_FUNCTION_EXTRACTOR"]
            puts "FunctionExtractor: Needed functions: #{needed_functions.inspect}"
          end
          
          function_hash = {}
          needed_functions.each do |fn_name|
            begin
              qualified_name = fn_name.to_s # Ensure we use string for RegistryV2 lookup
              kernel = registry_v2.get_executable_kernel(qualified_name)
              
              # Store under both original name and string name for compatibility
              function_hash[fn_name] = kernel
              function_hash[qualified_name] = kernel
              
              # Also store the symbol version if original was string
              if fn_name.is_a?(String)
                symbol_name = case fn_name
                             when "core.not" then :not
                             when "core.and" then :and
                             when "core.or" then :or
                             when "core.if" then :if
                             else fn_name.to_sym
                             end
                function_hash[symbol_name] = kernel
              end
              
              if ENV["DEBUG_FUNCTION_EXTRACTOR"]
                puts "  #{fn_name} -> #{kernel.class}"
              end
            rescue => e
              puts "ERROR: Failed to get kernel for #{fn_name}: #{e.message}"
              raise
            end
          end
          
          if ENV["DEBUG_FUNCTION_EXTRACTOR"]
            puts "FunctionExtractor: Built hash with #{function_hash.size} functions"
          end
          
          function_hash
        end
      end
    end
  end
end
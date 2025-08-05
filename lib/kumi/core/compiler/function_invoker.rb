module Kumi
  module Core
    module Compiler
      module FunctionInvoker
        private

        def invoke_function(name, arg_fns, ctx, loc)
          fn = Kumi::Registry.fetch(name)
          values = arg_fns.map { |fn| fn.call(ctx) }

          # REMOVED AUTO-FLATTENING: Let operations work on the structure they receive
          # If flattening is needed, it should be handled by explicit operation modes
          # in the InputElementReference compilation, not here.
          fn.call(*values)
        rescue StandardError => e
          # Preserve original error class and backtrace while adding context
          enhanced_message = "Error calling fn(:#{name}) at #{loc}: #{e.message}"

          if e.is_a?(Kumi::Core::Errors::Error)
            # Re-raise Kumi errors with enhanced message but preserve type
            e.define_singleton_method(:message) { enhanced_message }
            raise e
          else
            # For non-Kumi errors, wrap in RuntimeError but preserve original error info
            runtime_error = Errors::RuntimeError.new(enhanced_message)
            runtime_error.set_backtrace(e.backtrace)
            runtime_error.define_singleton_method(:cause) { e }
            raise runtime_error
          end
        end

        def invoke_function_with_flattening(name, arg_fns, ctx, loc, _original_args, _flattening_info)
          fn = Kumi::Registry.fetch(name)

          # Use pre-computed flattening indices from analysis
          compilation_meta = @analysis.state[:broadcasts]&.dig(:compilation_metadata, @current_declaration)
          flatten_indices = compilation_meta&.dig(:function_call_strategy, :flatten_argument_indices) || []

          values = arg_fns.map.with_index do |arg_fn, index|
            value = arg_fn.call(ctx)
            flatten_indices.include?(index) ? flatten_completely(value) : value
          end

          fn.call(*values)
        rescue StandardError => e
          enhanced_message = "Error calling fn(:#{name}) at #{loc}: #{e.message}"
          runtime_error = Errors::RuntimeError.new(enhanced_message)
          runtime_error.set_backtrace(e.backtrace)
          runtime_error.define_singleton_method(:cause) { e }
          raise runtime_error
        end
      end
    end
  end
end

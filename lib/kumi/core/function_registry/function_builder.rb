# frozen_string_literal: true

module Kumi
  module Core
    module FunctionRegistry
      class FunctionBuilder
        # Rich, defaulted function entry
        class Entry
          # NOTE: Keep ctor args minimal; everything else has sensible defaults.
          attr_reader :fn, :arity, :param_types, :return_type, :description,
                      :reducer, :structure_function, :param_modes, :param_info

          # param_modes:  nil | ->(argc){[:elem,:scalar,...]} | {fixed: [...], variadic: :elem|:scalar}
          # param_info:   nil | ->(argc){[specs]} | {fixed: [...], variadic: {…}}
          #   where a spec is: { name:, type:, mode:, required:, default:, doc: }
          def initialize(
            fn:,
            arity: nil,                 # Integer (>=0) or -1 / nil for variadic
            param_types: nil,           # defaults to [:any] * arity (when fixed)
            return_type: :any,
            description: "",
            reducer: false,
            structure_function: false,
            param_modes: nil,
            param_info: nil
          )
            @fn                 = fn
            @arity              = arity
            @param_types        = param_types || default_param_types(arity)
            @return_type        = return_type
            @description        = description
            @reducer            = !!reducer
            @structure_function = !!structure_function
            @param_modes        = normalize_param_modes(param_modes, arity)
            @param_info         = normalize_param_info(param_info, arity, @param_types)
          end

          # Concrete modes for a call site
          def param_modes_for(argc)
            pm = @param_modes
            return pm.call(argc) if pm.respond_to?(:call)

            fixed = Array(pm[:fixed] || [])
            return fixed.first(argc) if argc <= fixed.size

            fixed + Array.new(argc - fixed.size, pm.fetch(:variadic, :elem))
          end

          # Concrete param specs for a call site
          # → [{name:, type:, mode:, required:, default:, doc:}, ...]
          def param_specs_for(argc)
            base = if @param_info.respond_to?(:call)
                     @param_info.call(argc)
                   else
                     fixed = Array(@param_info[:fixed] || [])
                     if argc <= fixed.size
                       fixed.first(argc)
                     else
                       fixed + Array.new(argc - fixed.size, @param_info.fetch(:variadic, {}))
                     end
                   end

            modes = param_modes_for(argc)
            types = expand_types_for(argc)

            base.each_with_index.map do |spec, i|
              {
                name: spec[:name]     || auto_name(i),
                type: spec[:type]     || types[i] || :any,
                mode: spec[:mode]     || modes[i] || :elem,
                required: spec.key?(:required) ? spec[:required] : true,
                default: spec[:default],
                doc: spec[:doc] || ""
              }
            end
          end

          private

          def default_param_types(arity)
            if arity.is_a?(Integer) && arity >= 0
              Array.new(arity, :any)
            else
              [] # variadic → types resolved per call
            end
          end

          def expand_types_for(argc)
            if @param_types.nil? || @param_types.empty?
              Array.new(argc, :any)
            elsif @param_types.length >= argc
              @param_types.first(argc)
            else
              @param_types + Array.new(argc - @param_types.length, @param_types.last || :any)
            end
          end

          def normalize_param_modes(pm, _arity)
            return pm if pm

            # Default: everything element-wise/broadcastable
            ->(argc) { Array.new(argc, :elem) }
          end

          def normalize_param_info(info, _arity, _types)
            return info if info

            # Default: synthesize from types/modes at call time
            ->(argc) { Array.new(argc) { {} } }
          end

          def auto_name(i) = :"arg#{i + 1}"
        end

        # ===== Helper constructors (unchanged usage; now benefit from defaults) =====

        def self.comparison(_name, description, op)
          Entry.new(
            fn: ->(a, b) { a.public_send(op, b) },
            arity: 2, param_types: %i[float float],
            return_type: :boolean, description: description
          )
        end

        def self.equality(_name, description, op)
          Entry.new(
            fn: ->(a, b) { a.public_send(op, b) },
            arity: 2, param_types: %i[any any],
            return_type: :boolean, description: description
          )
        end

        def self.math_binary(_name, description, op, return_type: :float)
          Entry.new(
            fn: ->(a, b) { a.public_send(op, b) },
            arity: 2, param_types: %i[float float],
            return_type: return_type, description: description
          )
        end

        def self.math_unary(_name, description, op, return_type: :float)
          Entry.new(
            fn: proc(&op),
            arity: 1, param_types: [:float],
            return_type: return_type, description: description
          )
        end

        def self.string_unary(_name, description, op)
          Entry.new(
            fn: ->(s) { s.to_s.public_send(op) },
            arity: 1, param_types: [:string],
            return_type: :string, description: description
          )
        end

        def self.string_binary(_name, description, op, return_type: :string)
          Entry.new(
            fn: ->(s, x) { s.to_s.public_send(op, x.to_s) },
            arity: 2, param_types: %i[string string],
            return_type: return_type, description: description
          )
        end

        def self.logical_variadic(_name, description, op)
          Entry.new(
            fn: ->(*conds) { conds.flatten.public_send(op) },
            arity: -1, param_types: [:boolean],
            return_type: :boolean, description: description
          )
        end

        def self.collection_unary(_name, description, op, return_type: :boolean, reducer: false, structure_function: false)
          Entry.new(
            fn: proc(&op),
            arity: 1, param_types: [Kumi::Core::Types.array(:any)],
            return_type: return_type, description: description,
            reducer: reducer, structure_function: structure_function
          )
        end
      end
    end
  end
end

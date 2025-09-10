# lib/kumi/core/lir/build.rb
# Builders for each opcode. Keep params clear. Carry optional location.
module Kumi
  module Core
    module LIR
      module Build
        module_function

        # Constant
        # Params:
        #   value:     literal value
        #   dtype:     dtype of the literal
        #   as:        result register symbol/name
        #   location:  optional Location
        # Result: produces(result_register, stamp(dtype))
        def constant(value:, dtype:, as: nil, ids: nil, location: nil)
          as ||= ids.generate_temp
          Instruction.new(
            opcode: :Constant,
            result_register: as,
            stamp: Stamp.new(dtype: dtype),
            inputs: [],
            immediates: [Literal.new(value: value, dtype: dtype)],
            attributes: {},
            location:
          )
        end

        # LoadInput
        # Params:
        #   key:       String|Symbol top-level input key
        #   dtype:     dtype of the loaded field
        #   as:        result register
        #   location:  optional Location
        # Result: produces
        def load_input(key:, dtype:, as: nil, ids: nil, location: nil)
          as ||= ids.generate_temp
          Instruction.new(
            opcode: :LoadInput,
            result_register: as,
            stamp: Stamp.new(dtype: dtype),
            inputs: [],
            immediates: [Literal.new(value: key.to_s, dtype: :string)],
            attributes: {},
            location:
          )
        end

        # LoadDeclaration
        # Params:
        #   name:      declaration name
        #   dtype:     dtype of referenced declaration result
        #   axes:      axes of referenced declaration
        #   as:        result register
        #   location:  optional Location
        # Result: produces
        def load_declaration(name:, dtype:, axes:, as: nil, ids: nil, location: nil)
          as ||= ids.generate_temp
          Instruction.new(
            opcode: :LoadDeclaration,
            result_register: as,
            stamp: Stamp.new(dtype: dtype),
            inputs: [],
            immediates: [Literal.new(value: name.to_s, dtype: :string)],
            attributes: { axes: Array(axes).map!(&:to_sym) },
            location:
          )
        end

        # LoadField
        # Params:
        #   object_register: register holding a Hash-like object
        #   key:             field key to access
        #   dtype:           dtype of the field
        #   as:              result register
        #   location:        optional Location
        # Result: produces
        def load_field(object_register:, key:, dtype:, as: nil, ids: nil, location: nil)
          as ||= ids.generate_temp
          Instruction.new(
            opcode: :LoadField,
            result_register: as,
            stamp: Stamp.new(dtype: dtype),
            inputs: [object_register],
            immediates: [Literal.new(value: key.to_s, dtype: :string)],
            attributes: {},
            location:
          )
        end

        # LoopStart
        # Params:
        #   collection_register: register holding the array to iterate
        #   axis:                Symbol axis name
        #   as_element:          register name for the element within loop body
        #   as_index:            register name for the numeric index
        #   id:                  optional loop id; generated if nil
        #   location:            optional Location
        # Result: does not produce
        def loop_start(collection_register:, axis:, as_element:, as_index:, id: nil, ids: nil, location: nil)
          Instruction.new(
            opcode: :LoopStart,
            result_register: nil,
            stamp: nil,
            inputs: [collection_register],
            immediates: [],
            attributes: { axis: axis.to_sym, as_element:, as_index:, id: id || ids.generate_loop_id },
            location:
          )
        end

        # LoopEnd
        # Params:
        #   location: optional Location
        # Result: does not produce
        def loop_end(location: nil)
          Instruction.new(
            opcode: :LoopEnd,
            result_register: nil,
            stamp: nil,
            inputs: [],
            immediates: [],
            attributes: {},
            location:
          )
        end

        # KernelCall
        # Params:
        #   function:   String kernel id (e.g., "core.mul")
        #   args:       Array of register names
        #   out_dtype:  dtype of the result
        #   as:         result register
        #   location:   optional Location
        # Result: produces
        def kernel_call(function:, args:, out_dtype:, as: nil, ids: nil, location: nil)
          as ||= ids.generate_temp
          Instruction.new(
            opcode: :KernelCall,
            result_register: as,
            stamp: Stamp.new(dtype: out_dtype),
            inputs: args,
            immediates: [],
            attributes: { fn: function.to_s },
            location:
          )
        end

        # Select
        # Params:
        #   cond:       register name (boolean)
        #   on_true:    register name
        #   on_false:   register name
        #   out_dtype:  dtype of the result
        #   as:         result register
        #   location:   optional Location
        # Result: produces
        def select(cond:, on_true:, on_false:, out_dtype:, as: nil, ids: nil, location: nil)
          as ||= ids.generate_temp
          Instruction.new(
            opcode: :Select,
            result_register: as,
            stamp: Stamp.new(dtype: out_dtype),
            inputs: [cond, on_true, on_false],
            immediates: [],
            attributes: {},
            location:
          )
        end

        # DeclareAccumulator
        # Params:
        #   name:     Symbol accumulator name
        #   initial:  Literal identity value
        #   location: optional Location
        # Result: does not produce
        def declare_accumulator(initial:, location: nil, ids: nil, name: nil)
          name ||= ids.generate_acc
          Instruction.new(
            opcode: :DeclareAccumulator,
            result_register: name.to_sym,
            stamp: Stamp.new(dtype: initial.dtype),
            inputs: [],
            immediates: [initial],
            attributes: {},
            location:
          )
        end

        # Accumulate
        # Params:
        #   accumulator: Symbol accumulator name
        #   function:    String kernel id (e.g., "core.add")
        #   value_register: register providing the value to accumulate
        #   location:      optional Location
        # Result: does not produce
        def accumulate(accumulator:, function:, value_register:, dtype:, location: nil)
          Instruction.new(
            opcode: :Accumulate,
            result_register: accumulator.to_sym,
            stamp: Stamp.new(dtype: dtype),
            inputs: [value_register],
            immediates: [],
            attributes: { fn: function.to_s },
            location:
          )
        end

        # LoadAccumulator
        # Params:
        #   name:     Symbol accumulator name
        #   dtype:    dtype of the accumulator
        #   as:       result register
        #   location: optional Location
        # Result: produces
        def load_accumulator(accumulator:, dtype:, ids:, location: nil)
          as = ids.generate_temp
          Instruction.new(
            opcode: :LoadAccumulator,
            result_register: as,
            stamp: Stamp.new(dtype: dtype),
            inputs: [accumulator.to_sym],
            immediates: [],
            attributes: {},
            location:
          )
        end

        # MakeTuple
        # Params:
        #   elements: Array of registers
        #   out_dtype: tuple dtype
        #   as: result register
        # Result: produces tuple
        def make_tuple(elements:, out_dtype:, as: nil, ids: nil, location: nil)
          as ||= ids.generate_temp
          Instruction.new(
            opcode: :MakeTuple,
            result_register: as,
            stamp: Stamp.new(dtype: out_dtype),
            inputs: elements,
            immediates: [],
            attributes: {},
            location:
          )
        end

        # MakeObject
        # Params:
        #   keys:   Array<String|Symbol> in the same order as values
        #   values: Array of registers
        #   out_dtype: object dtype (or :object)
        #   as: result
        def make_object(keys:, values:, out_dtype:, as: nil, ids: nil, location: nil)
          as ||= ids.generate_temp
          Instruction.new(
            opcode: :MakeObject,
            result_register: as,
            stamp: Stamp.new(dtype: out_dtype),
            inputs: values,
            immediates: keys.map { |k| Literal.new(value: k.to_s, dtype: :string) },
            attributes: {},
            location: location
          )
        end

        # TupleGet (optional)
        # Params:
        #   tuple: register
        #   index: Integer
        #   out_dtype: element dtype
        #   as: result
        def tuple_get(tuple:, index:, out_dtype:, as: Ids.generate_temp, location: nil)
          Instruction.new(
            opcode: :TupleGet,
            result_register: as,
            stamp: Stamp.new(dtype: out_dtype),
            inputs: [tuple],
            immediates: [Literal.new(value: Integer(index), dtype: :i32)],
            attributes: {},
            location: location
          )
        end

        # Yield
        # Opcode: Yield
        # Semantics:
        # - Exactly one per declaration.
        # - Must be the last instruction in the declaration.
        # - The declaration's result axes are Γ, the active loop stack at the Yield site
        #   (i.e., the sequence of surrounding LoopStart frames).
        # - The yielded register's stamp.dtype is the declaration's result dtype.
        # Codegen rule:
        # - If Γ == [], return the yielded scalar.
        # - If Γ != [], materialize a container shaped by Γ and write the yielded value
        #   at each iteration of the surrounding loops.
        # Params:
        #   result_register: register that holds the final value
        #   location:        optional Location
        # Result: does not produce
        def yield(result_register:, location: nil)
          Instruction.new(
            opcode: :Yield,
            result_register: nil,
            stamp: nil,
            inputs: [result_register],
            immediates: [],
            attributes: {},
            location:
          )
        end
      end
    end
  end
end

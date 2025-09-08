# frozen_string_literal: true

module Kumi
  module Support
    class LIRPrinter
      LIR = Kumi::Core::LIR

      # Public: print all declarations
      # ops_by_decl: { "name" => { operations: [Instruction...] } }
      def self.print(ops_by_decl, show_stamps: true, show_locations: false)
        out = +"(LIR\n"
        ops_by_decl.each do |name, h|
          out << "  (Declaration #{name}\n"
          out << indent(print_instructions(h[:operations], show_stamps:, show_locations:), 2)
          out << "  )\n"
        end
        out << ")\n"
      end

      # Public: print a single instruction list
      def self.print_instructions(instructions, show_stamps: true, show_locations: false)
        new(show_stamps:, show_locations:).print_instructions(instructions)
      end

      def initialize(show_stamps:, show_locations:)
        @show_stamps = show_stamps
        @show_locations = show_locations
      end

      def print_instructions(instructions)
        out = +""
        indent = 0
        instructions.each do |ins|
          case ins.opcode
          when :LoopStart
            out << "  " * indent
            out << loop_start_line(ins) << nl(ins)
            indent += 1
          when :LoopEnd
            indent -= 1
            out << "  " * indent
            out << "end_loop" << nl(ins)
          else
            out << "  " * indent
            out << instr_line(ins) << nl(ins)
          end
        end
        out
      end

      private

      def instr_line(ins)
        res = ins.result_register ? "#{fmt_reg(ins.result_register)} = " : ""
        case ins.opcode
        when :Constant
          lit = ins.immediates&.first
          "#{res}const #{fmt_lit(lit)}#{stamp(ins)}"
        when :LoadInput
          key = ins.immediates&.first&.value
          "#{res}load_input #{fmt_key(key)}#{stamp(ins)}"
        when :LoadDeclaration
          name = ins.immediates&.first&.value
          axes = ins.attributes[:axes] || []
          axes_str = axes.empty? ? "" : " axes=[#{axes.join(', ')}]"
          "#{res}load_decl #{name}#{axes_str}#{stamp(ins)}"
        when :LoadField
          key = ins.immediates&.first&.value
          "#{res}load_field #{only(ins.inputs)}[#{fmt_key(key)}]#{stamp(ins)}"
        when :KernelCall
          fn = ins.attributes[:fn]
          "#{res}call #{fn}(#{list(ins.inputs)})#{stamp(ins)}"
        when :Select
          c,t,f = ins.inputs
          "#{res}select #{fmt_reg(c)}, #{fmt_reg(t)}, #{fmt_reg(f)}#{stamp(ins)}"
        when :DeclareAccumulator
          name = ins.attributes[:name]
          init = ins.immediates&.first
          "acc.declare #{name}=#{fmt_lit(init)}"
        when :Accumulate
          name = ins.attributes[:accumulator]
          fn   = ins.attributes[:function]
          v    = only(ins.inputs)
          "acc.add #{name} using #{fn} <- #{fmt_reg(v)}"
        when :LoadAccumulator
          name = ins.attributes[:name]
          "#{res}acc.load #{name}#{stamp(ins)}"
        when :MakeTuple
          "#{res}make_tuple(#{list(ins.inputs)})#{stamp(ins)}"
        when :MakeObject
          keys = (ins.immediates || []).map { |l| l.value }
          pairs = keys.zip(ins.inputs || []).map { |k,r| "#{k}: #{fmt_reg(r)}" }.join(", ")
          "#{res}make_object{#{pairs}}#{stamp(ins)}"
        when :TupleGet
          idx = ins.immediates&.first&.value
          "#{res}tuple_get #{fmt_reg(only(ins.inputs))}[#{idx}]#{stamp(ins)}"
        when :Yield
          "yield #{fmt_reg(only(ins.inputs))}"
        else
          # Fallback
          attrs = fmt_attrs(ins.attributes)
          imms  = fmt_imms(ins.immediates)
          "#{res}#{ins.opcode} #{list(ins.inputs)}#{imms}#{attrs}#{stamp(ins)}"
        end
      end

      def loop_start_line(ins)
        axis = ins.attributes[:axis]
        as_e = ins.attributes[:as_element]
        as_i = ins.attributes[:as_index]
        id   = ins.attributes[:id]
        coll = fmt_reg(only(ins.inputs))
        "loop #{axis} id=#{id} in #{coll} as el=#{fmt_reg(as_e)}, idx=#{fmt_reg(as_i)}"
      end

      # ---- small helpers ----

      def stamp(ins)
        return "" unless @show_stamps && ins.stamp
        " :: #{ins.stamp.dtype}"
      end

      def nl(ins)
        return "\n" unless @show_locations && ins.location
        loc = ins.location
        "  ; #{loc.file}:#{loc.line}:#{loc.column}\n"
      end

      def fmt_reg(r) = r.is_a?(Symbol) ? "%#{r}" : r.inspect
      def fmt_key(k) = k.inspect
      def fmt_lit(l) = l ? l.value.inspect : "nil"
      def list(arr)  = Array(arr).map { fmt_reg(_1) }.join(", ")
      def only(arr)  = Array(arr).first
      def fmt_attrs(h) = h && !h.empty? ? " #{h.map { |k,v| "#{k}=#{v.inspect}" }.join(' ')}" : ""
      def fmt_imms(imm) = imm && !imm.empty? ? " [#{imm.map { |l| fmt_lit(l) }.join(', ')}]" : ""

      def self.indent(str, n)
        pad = " " * n
        str.lines.map { |ln| pad + ln }.join
      end
    end
  end
end

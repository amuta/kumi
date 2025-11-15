# frozen_string_literal: true

require "spec_helper"

RSpec.describe "IR::DF Examples" do
  def new_builder(function_name)
    graph = Kumi::IR::DF::Graph.new(name: :examples)
    fn = Kumi::IR::DF::Function.new(name: function_name, blocks: [Kumi::IR::Base::Block.new(name: :entry)])
    graph.add_function(fn)
    [graph, fn, Kumi::IR::DF::Builder.new(ir_module: graph, function: fn)]
  end

  let(:int_type) { ir_types.scalar(:integer) }

  describe "Simple Math – scalar map (golden/simple_math)" do
    it "represents elementwise add with no axes" do
      _graph, fn, builder = new_builder(:sum)
      builder.load_input(result: :x, key: :x, axes: [], dtype: int_type)
      builder.load_input(result: :y, key: :y, axes: [], dtype: int_type)

      builder.map(result: :sum, fn: :"core.add", args: %i[x y], axes: [], dtype: int_type)

      instr = fn.entry_block.instructions.last
      expect(instr.opcode).to eq(:map)
      expect(instr.axes).to eq([])
      expect(instr.inputs).to eq(%i[x y])
      expect(instr.attributes[:fn]).to eq(:"core.add")
      expect(instr.metadata[:dtype]).to eq(int_type)
    end
  end

  describe "Reduction retains axis metadata" do
    it "records reducer axes and over_axes" do
      _graph, fn, builder = new_builder(:total_payroll)
      departments = builder.load_input(result: :departments, key: :departments, axes: %i[departments employees], dtype: int_type)
      dept = builder.load_field(result: :departments_dept, object: :departments, field: :dept, axes: %i[departments employees], dtype: int_type)
      employees = builder.load_field(result: :departments_employees, object: :departments_dept, field: :employees, axes: %i[departments employees], dtype: int_type)
      emp = builder.load_field(result: :departments_emp, object: :departments_employees, field: :emp, axes: %i[departments employees], dtype: int_type)
      salaries = builder.load_field(result: :salaries, object: :departments_emp, field: :salary, axes: %i[departments employees], dtype: int_type)

      builder.reduce(
        result: :total_payroll,
        fn: :"agg.sum",
        arg: :salaries,
        axes: %i[departments],
        over_axes: %i[employees],
        dtype: int_type
      )

      reduce = fn.entry_block.instructions.last
      expect(reduce.opcode).to eq(:reduce)
      expect(reduce.axes).to eq(%i[departments])
      expect(reduce.attributes[:over_axes]).to eq(%i[employees])
      expect(reduce.attributes[:fn]).to eq(:"agg.sum")
    end
  end

  describe "Select used as predicate before reduction" do
    it "keeps select elementwise before the reduce" do
      _graph, fn, builder = new_builder(:manager_count)
      departments = builder.load_input(result: :departments, key: :departments, axes: %i[departments employees], dtype: ir_types.scalar(:string))
      dept = builder.load_field(result: :departments_dept, object: :departments, field: :dept, axes: %i[departments employees], dtype: ir_types.scalar(:string))
      employees = builder.load_field(result: :departments_employees, object: :departments_dept, field: :employees, axes: %i[departments employees], dtype: ir_types.scalar(:string))
      emp = builder.load_field(result: :departments_emp, object: :departments_employees, field: :emp, axes: %i[departments employees], dtype: ir_types.scalar(:string))
      roles = builder.load_field(result: :roles, object: :departments_emp, field: :role, axes: %i[departments employees], dtype: ir_types.scalar(:string))
      builder.constant(result: :manager_label, value: "manager", axes: [], dtype: ir_types.scalar(:string))
      builder.constant(result: :one, value: 1, axes: [], dtype: int_type)
      builder.constant(result: :zero, value: 0, axes: [], dtype: int_type)

      builder.map(
        result: :is_manager,
        fn: :"core.eq",
        args: %i[roles manager_label],
        axes: %i[departments employees],
        dtype: ir_types.scalar(:boolean)
      )

      builder.select(
        result: :manager_flag,
        cond: :is_manager,
        on_true: :one,
        on_false: :zero,
        axes: %i[departments employees],
        dtype: int_type
      )

      builder.reduce(
        result: :manager_count,
        fn: :"agg.sum",
        arg: :manager_flag,
        axes: %i[departments],
        over_axes: %i[employees],
        dtype: int_type
      )

      select_instr = fn.entry_block.instructions[-2]
      expect(select_instr.opcode).to eq(:select)
      expect(select_instr.axes).to eq(%i[departments employees])
      expect(select_instr.inputs).to eq(%i[is_manager one zero])
    end
  end

  describe "Object assembly references other declarations" do
    it "builds elementwise hashes referencing declaration refs" do
      _graph, fn, builder = new_builder(:department_summary)
      departments = builder.load_input(result: :departments, key: :departments, axes: %i[departments], dtype: ir_types.scalar(:string))
      dept = builder.load_field(result: :departments_dept, object: :departments, field: :dept, axes: %i[departments], dtype: ir_types.scalar(:string))
      builder.load_field(result: :name, object: :departments_dept, field: :name, axes: %i[departments], dtype: ir_types.scalar(:string))
      builder.decl_ref(result: :total_payroll, name: :total_payroll, axes: %i[departments], dtype: int_type)
      builder.decl_ref(result: :manager_count, name: :manager_count, axes: %i[departments], dtype: int_type)

      builder.make_object(
        result: :department_summary,
        inputs: %i[name total_payroll manager_count],
        keys: %i[name total_payroll manager_count],
        axes: %i[departments],
        dtype: ir_types.scalar(:hash)
      )

      object_instr = fn.entry_block.instructions.last
      expect(object_instr.opcode).to eq(:make_object)
      expect(object_instr.axes).to eq(%i[departments])
      expect(object_instr.inputs).to eq(%i[name total_payroll manager_count])
      expect(object_instr.attributes[:keys]).to eq(%i[name total_payroll manager_count])
    end
  end

  describe "Array literals and element access" do
    it "builds arrays and gathers elements with oob policy" do
      _graph, fn, builder = new_builder(:array_ops)
      builder.constant(result: :a, value: 1, axes: [], dtype: int_type)
      builder.constant(result: :b, value: 2, axes: [], dtype: int_type)
      arr = builder.array_build(result: :arr, elements: %i[a b], axes: [], dtype: ir_types.array(int_type))
      builder.constant(result: :idx, value: 0, axes: [], dtype: int_type)
      builder.array_get(result: :first, array: arr, index: :idx, axes: [], dtype: int_type, oob: :wrap)
      builder.array_len(result: :len, array: arr, axes: [], dtype: int_type)

      instrs = fn.entry_block.instructions
      expect(instrs.map(&:opcode)).to include(:array_build, :array_get, :array_len)

      get_instr = instrs.find { _1.opcode == :array_get }
      expect(get_instr.attributes[:oob]).to eq(:wrap)
    end
  end

  describe "Axis index references" do
    it "emits axis_index ops for IndexRef nodes" do
      snast = snast_factory.build do |b|
        idx = snast_factory.index_ref(name: :i, input_fqn: "x", axes: [:rows], dtype: ir_types.scalar(:integer))
        b.declaration(:idx, axes: [:rows], dtype: ir_types.scalar(:integer)) { idx }
      end

      lowering = Kumi::IR::DF::Lower.new(snast_module: snast, registry: double(resolve_function: :unused), input_table: {}, input_metadata: {})
      graph = lowering.call
      instrs = graph.fetch_function(:idx).entry_block.instructions
      expect(instrs.map(&:opcode)).to include(:axis_index)
    end

    it "lowers fold nodes" do
      snast = snast_factory.build do |b|
        arg = snast_factory.input_ref(path: %i[data], axes: [:rows], dtype: ir_types.array(int_type))
        fold = snast_factory.fold(fn: :core_sum, arg:, axes: [:rows], dtype: int_type, meta: { function: :core_sum })
        b.declaration(:fold_sum, axes: [:rows], dtype: int_type) { fold }
      end

      graph = Kumi::IR::DF::Lower.new(snast_module: snast, registry: double(resolve_function: :core_sum), input_table: {}, input_metadata: {}).call
      instrs = graph.fetch_function(:fold_sum).entry_block.instructions
      expect(instrs.map(&:opcode)).to include(:fold)
    end

    it "lowers import calls" do
      snast = snast_factory.build do |b|
        arg = snast_factory.input_ref(path: %i[x], axes: [], dtype: int_type)
        import = Kumi::Core::NAST::ImportCall.new(
          fn_name: :remote_fn,
          args: [arg],
          input_mapping_keys: %i[a],
          source_module: :remote,
          id: 1,
          meta: { stamp: { axes: [], dtype: int_type } }
        )
        b.declaration(:imported, axes: [], dtype: int_type) { import }
      end

      graph = Kumi::IR::DF::Lower.new(snast_module: snast, registry: double(resolve_function: :unused), input_table: {}, input_metadata: {}).call
      instrs = graph.fetch_function(:imported).entry_block.instructions
      expect(instrs.map(&:opcode)).to include(:import_call)
    end

    it "lowers shift into axis_shift" do
      int = ir_types.scalar(:integer)
      snast = snast_factory.build do |b|
        src = snast_factory.input_ref(path: %i[cells value], axes: %i[cells], dtype: int)
        offset = snast_factory.const(1, dtype: int)
        shift_call = snast_factory.call(
          fn: :shift,
          args: [src, offset],
          axes: %i[cells],
          dtype: int,
          opts: { policy: :clamp }
        )
        b.declaration(:shifted, axes: %i[cells], dtype: int) { shift_call }
      end

      registry = double(
        resolve_function: :"core.shift",
        function: { options: { policy: :zero, axis_offset: 0 } }
      )
      graph = Kumi::IR::DF::Lower.new(snast_module: snast, registry:, input_table: {}, input_metadata: {}).call
      instrs = graph.fetch_function(:shifted).entry_block.instructions
      shift = instrs.find { _1.opcode == :axis_shift }
      expect(shift).not_to be_nil
      expect(shift.attributes[:policy]).to eq(:clamp)
      expect(shift.attributes[:axis]).to eq(:cells)
      expect(shift.attributes[:offset]).to eq(1)
    end
    it "broadcasts scalar arguments to target axes" do
      int = ir_types.scalar(:integer)
      snast = snast_factory.build do |b|
        rows = snast_factory.input_ref(path: %i[rows], axes: %i[rows], dtype: int)
        one = snast_factory.const(1, dtype: int)
        call = snast_factory.call(fn: :core_add, args: [rows, one], axes: %i[rows], dtype: int)
        b.declaration(:broadcast_add, axes: %i[rows], dtype: int) { call }
      end

      graph = Kumi::IR::DF::Lower.new(snast_module: snast, registry: double(resolve_function: :"core.add"), input_table: {}, input_metadata: {}).call
      instrs = graph.fetch_function(:broadcast_add).entry_block.instructions
      expect(instrs.map(&:opcode)).to include(:axis_broadcast)
    end
  end
end

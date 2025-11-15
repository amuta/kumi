# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::DF::Lower do
  let(:types) { ir_types }

  def build_simple_math_snast
    snast_factory.build do |b|
      x = snast_factory.input_ref(path: %i[x], axes: [], dtype: types.scalar(:integer))
      y = snast_factory.input_ref(path: %i[y], axes: [], dtype: types.scalar(:integer))
      body = snast_factory.call(
        fn: :core_add,
        args: [x, y],
        axes: [],
        dtype: types.scalar(:integer),
        meta: { function: :"core.add" }
      )
      b.declaration(:sum, axes: [], dtype: types.scalar(:integer)) { body }
    end
  end

  describe "lowering a scalar map" do
    it "produces DF graph instructions" do
      snast = build_simple_math_snast
      registry = instance_double("Registry", resolve_function: :"core.add")
      lower = described_class.new(
        snast_module: snast,
        registry: registry,
        input_table: {}
      )

      graph = lower.call

      fn = graph.fetch_function(:sum)
      instrs = fn.entry_block.instructions

      expect(instrs.map(&:opcode)).to eq(%i[load_input load_input map])

      map = instrs.last
      expect(map.axes).to eq([])
      expect(map.inputs.size).to eq(2)
      expect(map.attributes[:fn]).to eq(:"core.add")
      expect(map.metadata[:dtype]).to eq(types.scalar(:integer))
    end
  end

  describe "lowering a reduction with select predicate" do
    it "creates select and reduce instructions" do
      snast = snast_factory.build do |b|
        roles = snast_factory.input_ref(
          path: %i[departments dept employees emp role],
          axes: %i[departments employees],
          dtype: types.scalar(:string)
        )
        manager = snast_factory.const("manager", dtype: types.scalar(:string))
        cond = snast_factory.call(
          fn: :core_eq,
          args: [roles, manager],
          axes: %i[departments employees],
          dtype: types.scalar(:boolean),
          meta: { function: :"core.eq" }
        )
        one = snast_factory.const(1, dtype: types.scalar(:integer))
        zero = snast_factory.const(0, dtype: types.scalar(:integer))
        select = snast_factory.select(
          cond: cond,
          on_true: one,
          on_false: zero,
          axes: %i[departments employees],
          dtype: types.scalar(:integer)
        )
        reduce = snast_factory.reduce(
          fn: :agg_sum,
          arg: select,
          over: [:employees],
          axes: %i[departments],
          dtype: types.scalar(:integer),
          meta: { function: :"agg.sum" }
        )
        b.declaration(:manager_count, axes: %i[departments], dtype: types.scalar(:integer)) { reduce }
      end

      lower = described_class.new(snast_module: snast, registry: double(resolve_function: :resolved), input_table: {})
      graph = lower.call

      instrs = graph.fetch_function(:manager_count).entry_block.instructions
      expect(instrs.map(&:opcode)).to include(:select, :reduce)

      select_instr = instrs.find { _1.opcode == :select }
      expect(select_instr.inputs.length).to eq(3)
      expect(select_instr.axes).to eq(%i[departments employees])

      reduce_instr = instrs.find { _1.opcode == :reduce }
      expect(reduce_instr.attributes[:over_axes]).to eq(%i[employees])
      expect(reduce_instr.axes).to eq(%i[departments])
    end
  end

  describe "lowering object assembly with declaration refs" do
    it "emits decl_ref and make_object instructions" do
      snast = snast_factory.build do |b|
        total = snast_factory.const(0, dtype: types.scalar(:integer))
        mgr = snast_factory.const(1, dtype: types.scalar(:integer))
        b.declaration(:total_payroll, axes: %i[departments], dtype: types.scalar(:integer)) { total }
        b.declaration(:manager_count, axes: %i[departments], dtype: types.scalar(:integer)) { mgr }

        name = snast_factory.input_ref(path: %i[departments dept name], axes: %i[departments], dtype: types.scalar(:string))
        hash = snast_factory.hash(
          pairs: [
            snast_factory.pair(key: :name, value: name, axes: %i[departments], dtype: types.scalar(:string)),
            snast_factory.pair(key: :total_payroll, value: snast_factory.ref(name: :total_payroll, axes: %i[departments], dtype: types.scalar(:integer)), axes: %i[departments], dtype: types.scalar(:integer)),
            snast_factory.pair(key: :manager_count, value: snast_factory.ref(name: :manager_count, axes: %i[departments], dtype: types.scalar(:integer)), axes: %i[departments], dtype: types.scalar(:integer))
          ],
          axes: %i[departments],
          dtype: types.scalar(:hash)
        )
        b.declaration(:department_summary, axes: %i[departments], dtype: types.scalar(:hash)) { hash }
      end

      lower = described_class.new(snast_module: snast, registry: double(resolve_function: :unused), input_table: {})
      graph = lower.call

      instrs = graph.fetch_function(:department_summary).entry_block.instructions
      expect(instrs.map(&:opcode)).to include(:decl_ref, :make_object)

      decl_instrs = instrs.select { _1.opcode == :decl_ref }
      expect(decl_instrs.map { _1.attributes[:name] }).to contain_exactly(:total_payroll, :manager_count)

      object_instr = instrs.find { _1.opcode == :make_object }
      expect(object_instr.attributes[:keys]).to eq(%i[name total_payroll manager_count])
      expect(object_instr.inputs.size).to eq(3)
    end
  end

  describe "lowering tuple literals" do
    it "creates array_build instructions" do
      snast = snast_factory.build do |b|
        tuple = snast_factory.tuple(
          args: [
            snast_factory.const(1, dtype: types.scalar(:integer)),
            snast_factory.const(2, dtype: types.scalar(:integer))
          ],
          axes: [],
          dtype: types.array(types.scalar(:integer))
        )
        b.declaration(:pair, axes: [], dtype: types.array(types.scalar(:integer))) { tuple }
      end

      lower = described_class.new(snast_module: snast, registry: double(resolve_function: :unused), input_table: {})
      graph = lower.call

      instrs = graph.fetch_function(:pair).entry_block.instructions
      expect(instrs.map(&:opcode)).to include(:array_build)
    end
  end

  describe "input access plan references" do
    it "attaches plan_ref attributes to load instructions" do
      snast = snast_factory.build do |b|
        value = snast_factory.input_ref(
          path: %i[rows col alive],
          axes: %i[rows col],
          dtype: types.scalar(:integer)
        )
        b.declaration(:alive_value, axes: %i[rows col], dtype: types.scalar(:integer)) { value }
      end

      plans = [
        Kumi::Core::Analyzer::Plans::InputPlan.new(
          source_path: %i[rows],
          axes: %i[rows col],
          dtype: types.scalar(:integer),
          key_policy: :indifferent,
          missing_policy: :error,
          navigation_steps: [{ kind: :property_access, key: "rows" }],
          path_fqn: "rows",
          open_axis: false
        ),
        Kumi::Core::Analyzer::Plans::InputPlan.new(
          source_path: %i[rows col],
          axes: %i[rows col],
          dtype: types.scalar(:integer),
          key_policy: :indifferent,
          missing_policy: :error,
          navigation_steps: [
            { kind: :property_access, key: "rows" },
            { kind: :property_access, key: "col" }
          ],
          path_fqn: "rows.col",
          open_axis: false
        ),
        Kumi::Core::Analyzer::Plans::InputPlan.new(
          source_path: %i[rows col alive],
          axes: %i[rows col],
          dtype: types.scalar(:integer),
          key_policy: :indifferent,
          missing_policy: :error,
          navigation_steps: [
            { kind: :property_access, key: "rows" },
            { kind: :property_access, key: "col" },
            { kind: :property_access, key: "alive" }
          ],
          path_fqn: "rows.col.alive",
          open_axis: false
        )
      ]

      lower = described_class.new(snast_module: snast, registry: double(resolve_function: :unused), input_table: plans)
      graph = lower.call

      instrs = graph.fetch_function(:alive_value).entry_block.instructions
      load_input, load_field_col, load_field_alive = instrs.first(3)

      expect(load_input.attributes[:plan_ref]).to eq("rows")
      expect(load_field_col.attributes[:plan_ref]).to eq("rows.col")
      expect(load_field_alive.attributes[:plan_ref]).to eq("rows.col.alive")
    end
  end
end

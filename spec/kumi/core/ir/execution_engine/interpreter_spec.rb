# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::IR::ExecutionEngine::Interpreter do
  # Helper to create IR structures
  def ir_module(decls)
    Kumi::Core::IR::Module.new(inputs: {}, decls: decls)
  end

  def ir_decl(name, ops)
    Kumi::Core::IR::Decl.new(name: name, kind: :value, shape: nil, ops: ops)
  end

  def ir_op(tag, attrs = {}, args = [])
    Kumi::Core::IR::Op.new(tag: tag, attrs: attrs, args: args)
  end

  def registry
    Kumi::Registry.functions
  end

  # Mock registry with basic functions

  describe ".run" do
    context "with scalar operations" do
      it "executes const operation" do
        ir = ir_module([
                         ir_decl(:x, [
                                   ir_op(:const, { value: 42 }),
                                   ir_op(:store, { name: :x }, [0])
                                 ])
                       ])

        result = described_class.run(ir, {}, accessors: {}, registry: registry)

        expect(result[:x][:k]).to eq(:scalar)
        expect(result[:x][:v]).to eq(42)
      end

      it "executes scalar map operation" do
        ir = ir_module([
                         ir_decl(:result, [
                                   ir_op(:const, { value: 10 }),
                                   ir_op(:const, { value: 20 }),
                                   ir_op(:map, { fn: :add, argc: 2 }, [0, 1]),
                                   ir_op(:store, { name: :result }, [2])
                                 ])
                       ])

        result = described_class.run(ir, {}, accessors: {}, registry: registry)

        expect(result[:result][:k]).to eq(:scalar)
        expect(result[:result][:v]).to eq(30)
      end

      it "executes load_input for scalar" do
        accessors = {
          "x:read" => ->(ctx) { 5 }
        }

        ir = ir_module([
                         ir_decl(:doubled, [
                                   ir_op(:load_input, { plan_id: "x:read", scope: [], is_scalar: true, has_idx: false }),
                                   ir_op(:const, { value: 2 }),
                                   ir_op(:map, { fn: :multiply, argc: 2 }, [0, 1]),
                                   ir_op(:store, { name: :doubled }, [2])
                                 ])
                       ])

        result = described_class.run(ir, { input: { x: 5 } }, accessors: accessors, registry: registry)

        expect(result[:doubled][:k]).to eq(:scalar)
        expect(result[:doubled][:v]).to eq(10)
      end
    end

    context "with vector operations" do
      it "executes load_input for vector with indices" do
        accessors = {
          "items:each_indexed" => ->(ctx) { [[10, [0]], [20, [1]], [30, [2]]] }
        }

        ir = ir_module([
                         ir_decl(:items_vec, [
                                   ir_op(:load_input, { plan_id: "items:each_indexed", scope: [:items], is_scalar: false, has_idx: true }),
                                   ir_op(:store, { name: :items_vec }, [0])
                                 ])
                       ])

        result = described_class.run(ir, { input: {} }, accessors: accessors, registry: registry)

        expect(result[:items_vec][:k]).to eq(:vec)
        expect(result[:items_vec][:scope]).to eq([:items])
        expect(result[:items_vec][:has_idx]).to be true
        expect(result[:items_vec][:rows]).to eq([
                                                  { v: 10, idx: [0] },
                                                  { v: 20, idx: [1] },
                                                  { v: 30, idx: [2] }
                                                ])
      end

      it "executes vector map operation" do
        accessors = {
          "items:each_indexed" => ->(ctx) { [[2, [0]], [3, [1]]] }
        }

        ir = ir_module([
                         ir_decl(:doubled, [
                                   ir_op(:load_input, { plan_id: "items:each_indexed", scope: [:items], is_scalar: false, has_idx: true }),
                                   ir_op(:const, { value: 2 }),
                                   ir_op(:map, { fn: :multiply, argc: 2 }, [0, 1]),
                                   ir_op(:store, { name: :doubled }, [2])
                                 ])
                       ])

        result = described_class.run(ir, { input: {} }, accessors: accessors, registry: registry)

        expect(result[:doubled][:k]).to eq(:vec)
        expect(result[:doubled][:rows].map { |r| r[:v] }).to eq([4, 6])
      end

      it "broadcasts scalar over vector in map" do
        accessors = {
          "items.price:each_indexed" => ->(ctx) { [[100.0, [0]], [200.0, [1]]] },
          "tax_rate:read" => ->(ctx) { 1.1 }
        }

        ir = ir_module([
                         ir_decl(:prices_with_tax, [
                                   ir_op(:load_input,
                                         { plan_id: "items.price:each_indexed", scope: [:items], is_scalar: false, has_idx: true }),
                                   ir_op(:load_input, { plan_id: "tax_rate:read", scope: [], is_scalar: true, has_idx: false }),
                                   ir_op(:map, { fn: :multiply, argc: 2 }, [0, 1]),
                                   ir_op(:store, { name: :prices_with_tax }, [2])
                                 ])
                       ])

        result = described_class.run(ir, { input: {} }, accessors: accessors, registry: registry)

        expect(result[:prices_with_tax][:k]).to eq(:vec)
        values = result[:prices_with_tax][:rows].map { |r| r[:v] }
        expect(values[0]).to be_within(0.001).of(110.0)
        expect(values[1]).to be_within(0.001).of(220.0)
      end
    end

    context "with reduce operations" do
      it "reduces vector to scalar" do
        accessors = {
          "items:ravel" => ->(ctx) { [10, 20, 30] }
        }

        ir = ir_module([
                         ir_decl(:total, [
                                   ir_op(:load_input, { plan_id: "items:ravel", scope: [:items], is_scalar: false, has_idx: false }),
                                   ir_op(:reduce, { fn: :sum }, [0]),
                                   ir_op(:store, { name: :total }, [1])
                                 ])
                       ])

        result = described_class.run(ir, { input: {} }, accessors: accessors, registry: registry)

        expect(result[:total][:k]).to eq(:scalar)
        expect(result[:total][:v]).to eq(60)
      end
    end

    context "with lift operations" do
      it "lifts vector to nested structure" do
        accessors = {
          "matrix:each_indexed" => lambda { |ctx|
            [[1, [0, 0]], [2, [0, 1]], [3, [1, 0]], [4, [1, 1]]]
          }
        }

        ir = ir_module([
                         ir_decl(:nested, [
                                   ir_op(:load_input, { plan_id: "matrix:each_indexed", scope: %i[i j], is_scalar: false, has_idx: true }),
                                   ir_op(:lift, { to_scope: %i[i j] }, [0]),
                                   ir_op(:store, { name: :nested }, [1])
                                 ])
                       ])

        result = described_class.run(ir, { input: {} }, accessors: accessors, registry: registry)

        expect(result[:nested][:k]).to eq(:scalar)
        # VM lifts with full depth based on index dimensions
        # With rank-2 indices [i,j] and to_scope [:i, :j], depth = 2. group_rows
        #   groups by i then j, and at leaf returns the value.
        expect(result[:nested][:v]).to eq([[1, 2], [3, 4]])
      end
    end

    context "with array operations" do
      it "creates scalar array from scalars" do
        ir = ir_module([
                         ir_decl(:arr, [
                                   ir_op(:const, { value: 1 }),
                                   ir_op(:const, { value: 2 }),
                                   ir_op(:const, { value: 3 }),
                                   ir_op(:array, { count: 3 }, [0, 1, 2]),
                                   ir_op(:store, { name: :arr }, [3])
                                 ])
                       ])

        result = described_class.run(ir, {}, accessors: {}, registry: registry)

        expect(result[:arr][:k]).to eq(:scalar)
        expect(result[:arr][:v]).to eq([1, 2, 3])
      end

      it "creates vector array from mixed scalar and vector" do
        accessors = {
          "items:each_indexed" => ->(ctx) { [[10, [0]], [20, [1]]] }
        }

        ir = ir_module([
                         ir_decl(:mixed_array, [
                                   ir_op(:load_input, { plan_id: "items:each_indexed", scope: [:items], is_scalar: false, has_idx: true }),
                                   ir_op(:const, { value: 100 }),
                                   ir_op(:array, { count: 2 }, [0, 1]),
                                   ir_op(:store, { name: :mixed_array }, [2])
                                 ])
                       ])

        result = described_class.run(ir, { input: {} }, accessors: accessors, registry: registry)

        expect(result[:mixed_array][:k]).to eq(:vec)
        expect(result[:mixed_array][:rows].map { |r| r[:v] }).to eq([[10, 100], [20, 100]])
      end
    end

    context "with ref operations" do
      it "references previously stored values" do
        ir = ir_module([
                         ir_decl(:x, [
                                   ir_op(:const, { value: 10 }),
                                   ir_op(:store, { name: :x }, [0])
                                 ]),
                         ir_decl(:y, [
                                   ir_op(:ref, { name: :x }),
                                   ir_op(:const, { value: 2 }),
                                   ir_op(:map, { fn: :multiply, argc: 2 }, [0, 1]),
                                   ir_op(:store, { name: :y }, [2])
                                 ])
                       ])

        result = described_class.run(ir, {}, accessors: {}, registry: registry)

        expect(result[:x][:v]).to eq(10)
        expect(result[:y][:v]).to eq(20)
      end
    end

    context "with switch operations" do
      it "selects based on scalar condition" do
        ir = ir_module([
                         ir_decl(:result, [
                                   ir_op(:const, { value: true }),
                                   ir_op(:const, { value: "yes" }),
                                   ir_op(:const, { value: "no" }),
                                   ir_op(:switch, { cases: [[0, 1]], default: 2 }, []),
                                   ir_op(:store, { name: :result }, [3])
                                 ])
                       ])

        result = described_class.run(ir, {}, accessors: {}, registry: registry)

        expect(result[:result][:v]).to eq("yes")
      end

      it "uses default when no condition matches" do
        ir = ir_module([
                         ir_decl(:result, [
                                   ir_op(:const, { value: false }),
                                   ir_op(:const, { value: "yes" }),
                                   ir_op(:const, { value: "default" }),
                                   ir_op(:switch, { cases: [[0, 1]], default: 2 }, []),
                                   ir_op(:store, { name: :result }, [3])
                                 ])
                       ])

        result = described_class.run(ir, {}, accessors: {}, registry: registry)

        expect(result[:result][:v]).to eq("default")
      end
    end

    context "with align_to operations" do
      it "aligns vectors by prefix" do
        accessors = {
          "matrix:each_indexed" => lambda { |ctx|
            [[nil, [0, 0]], [nil, [0, 1]], [nil, [1, 0]]]
          },
          "row_sums:each_indexed" => lambda { |ctx|
            [[10, [0]], [20, [1]]]
          }
        }

        ir = ir_module([
                         ir_decl(:aligned, [
                                   ir_op(:load_input, { plan_id: "matrix:each_indexed", scope: %i[i j], is_scalar: false, has_idx: true }),
                                   ir_op(:load_input, { plan_id: "row_sums:each_indexed", scope: [:i], is_scalar: false, has_idx: true }),
                                   ir_op(:align_to, { to_scope: %i[i j], require_unique: false, on_missing: :nil }, [0, 1]),
                                   ir_op(:store, { name: :aligned }, [2])
                                 ])
                       ])

        result = described_class.run(ir, { input: {} }, accessors: accessors, registry: registry)

        expect(result[:aligned][:k]).to eq(:vec)
        expect(result[:aligned][:rows].map { |r| r[:v] }).to eq([10, 10, 20])
      end
    end

    context "with error handling" do
      xit "includes operation context in error messages" do
        # This is analzyer responsability!
        ir = ir_module([
                         ir_decl(:bad, [
                                   ir_op(:const, { value: 1 }),
                                   ir_op(:map, { fn: :unknown_function, argc: 1 }, [0]),
                                   ir_op(:store, { name: :bad }, [1])
                                 ])
                       ])

        expect do
          described_class.run(ir, {}, accessors: {}, registry: registry)
        end.to raise_error(/bad@op1 map: Unknown function: unknown_function/)
      end
    end

    context "with target parameter" do
      it "returns early when target is reached" do
        ir = ir_module([
                         ir_decl(:x, [
                                   ir_op(:const, { value: 10 }),
                                   ir_op(:store, { name: :x }, [0])
                                 ]),
                         ir_decl(:y, [
                                   ir_op(:const, { value: 20 }),
                                   ir_op(:store, { name: :y }, [0])
                                 ])
                       ])

        result = described_class.run(ir, { target: :x }, accessors: {}, registry: registry)

        expect(result).to have_key(:x)
        expect(result).not_to have_key(:y)
      end
    end
  end
end

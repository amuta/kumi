# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Kumi::Core::IR::Lowering::ArgAligner do
  SlotShape = Struct.new(:kind, :scope, :has_idx)
  
  let(:ops) { [] }
  let(:shapes) { {} }
  let(:shape_of) { ->(slot) { shapes[slot] } }
  let(:aligner) { described_class.new(shape_of: shape_of) }

  describe '#align!' do
    context 'with all scalar arguments' do
      it 'keeps scalars as-is' do
        shapes[0] = SlotShape.new(:scalar, [], false)
        shapes[1] = SlotShape.new(:scalar, [], false)
        
        result = aligner.align!(ops: ops, arg_slots: [0, 1], join_policy: nil)
        
        expect(result.slots).to eq([0, 1])
        expect(result.carrier_scope).to be_nil
        expect(result.emitted).to be_empty
        expect(ops).to be_empty
      end
    end

    context 'with single vector argument' do
      it 'keeps single vector as-is' do
        shapes[0] = SlotShape.new(:vec, [:i], true)
        shapes[1] = SlotShape.new(:scalar, [], false)
        
        result = aligner.align!(ops: ops, arg_slots: [0, 1], join_policy: nil)
        
        expect(result.slots).to eq([0, 1])
        expect(result.carrier_scope).to be_nil
        expect(result.emitted).to be_empty
        expect(ops).to be_empty
      end
    end

    context 'with same-scope vectors' do
      it 'keeps aligned vectors as-is' do
        shapes[0] = SlotShape.new(:vec, [:i], true)
        shapes[1] = SlotShape.new(:vec, [:i], true)
        
        result = aligner.align!(ops: ops, arg_slots: [0, 1], join_policy: nil)
        
        expect(result.slots).to eq([0, 1])
        expect(result.carrier_scope).to eq([:i])  # carrier is selected but no alignment needed
        expect(result.emitted).to be_empty
        expect(ops).to be_empty
      end
    end

    context 'with prefix-compatible vectors' do
      it 'emits AlignTo for prefix-compatible vectors' do
        shapes[0] = SlotShape.new(:vec, [:i, :j], true)  # carrier (longer)
        shapes[1] = SlotShape.new(:vec, [:i], true)      # prefix-compatible
        
        result = aligner.align!(ops: ops, arg_slots: [0, 1], join_policy: nil)
        
        expect(result.slots).to eq([0, 2])  # slot 1 becomes aligned slot 2
        expect(result.carrier_scope).to eq([:i, :j])
        expect(result.emitted).to eq([2])
        expect(ops.size).to eq(1)
        expect(ops[0].tag).to eq(:align_to)
        expect(ops[0].attrs[:to_scope]).to eq([:i, :j])
      end
    end

    context 'with cross-scope vectors' do
      it 'emits Join+Project for cross-scope vectors with zip policy' do
        shapes[0] = SlotShape.new(:vec, [:i], true)
        shapes[1] = SlotShape.new(:vec, [:j], true)
        
        result = aligner.align!(ops: ops, arg_slots: [0, 1], join_policy: :zip)
        
        # Should have: Join, Project(0), Project(1)
        expect(ops.size).to eq(3)
        expect(ops[0].tag).to eq(:join)
        expect(ops[0].attrs[:policy]).to eq(:zip)
        expect(ops[1].tag).to eq(:project)
        expect(ops[1].attrs[:index]).to eq(0)
        expect(ops[2].tag).to eq(:project)
        expect(ops[2].attrs[:index]).to eq(1)
        
        # Slots should point to projected results
        expect(result.slots).to eq([3, 4])  # project results at slots 3,4
        expect(result.emitted).to eq([2, 3, 4])  # join + 2 projects
      end

      it 'raises when cross-scope and no join_policy' do
        shapes[0] = SlotShape.new(:vec, [:i], true)
        shapes[1] = SlotShape.new(:vec, [:j], true)
        
        expect {
          aligner.align!(ops: ops, arg_slots: [0, 1], join_policy: nil)
        }.to raise_error(/requires join_policy/)
      end
    end

    context 'with mixed prefix-compatible and cross-scope vectors' do
      it 'handles both AlignTo and Join+Project' do
        shapes[0] = SlotShape.new(:vec, [:i, :j], true)  # carrier (longest)
        shapes[1] = SlotShape.new(:vec, [:i], true)      # prefix-compatible  
        shapes[2] = SlotShape.new(:vec, [:k], true)      # cross-scope
        
        result = aligner.align!(ops: ops, arg_slots: [0, 1, 2], join_policy: :zip)
        
        # Should have: AlignTo, Join, Project(0), Project(1)
        expect(ops.size).to eq(4)
        expect(ops[0].tag).to eq(:align_to)  # for prefix-compatible
        expect(ops[1].tag).to eq(:join)      # for cross-scope
        expect(ops[2].tag).to eq(:project)   # carrier projection
        expect(ops[3].tag).to eq(:project)   # cross-scope projection
        
        # Slots: aligned[1] → 3, aligned[0] → 5, aligned[2] → 6
        expect(result.slots).to eq([5, 3, 6])
        expect(result.emitted).to eq([3, 4, 5, 6])
      end
    end
  end
end
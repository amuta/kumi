# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::Testing::SnastFactory do
  describe ".build" do
    it "builds a SNAST module with stamped declarations" do
      mod = described_class.build do |b|
        b.declaration(:total_payroll, axes: %i[departments], dtype: :integer) do
          described_class.const(0, dtype: :integer)
        end
      end

      decl = mod.decls.fetch(:total_payroll)
      expect(decl).to be_a(Kumi::Core::NAST::Declaration)
      expect(decl.meta[:stamp][:axes]).to eq(%i[departments])
      expect(decl.meta[:stamp][:dtype]).to eq(Kumi::Core::Types.scalar(:integer))

      body = decl.body
      expect(body).to be_a(Kumi::Core::NAST::Const)
      expect(body.meta[:stamp][:dtype]).to eq(Kumi::Core::Types.scalar(:integer))
    end
  end

  describe ".input_ref" do
    it "normalizes dtype and copies key metadata" do
      dtype = Kumi::Core::Types.array(Kumi::Core::Types.scalar(:integer))
      node = described_class.input_ref(
        path: %i[departments],
        axes: %i[departments],
        dtype: dtype,
        key_chain: %i[employees salary]
      )

      expect(node.path).to eq(%i[departments])
      expect(node.key_chain).to eq(%i[employees salary])
      expect(node.meta[:stamp][:dtype]).to eq(dtype)
    end
  end
end

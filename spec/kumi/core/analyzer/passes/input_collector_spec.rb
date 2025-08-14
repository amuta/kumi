# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Analyzer::Passes::InputCollector do
  include ASTFactory

  State = Struct.new(:data) do
    def with(k, v)
      self.data ||= {}
      self.data[k] = v
      self
    end
  end
  def build_schema(inputs) = Struct.new(:inputs).new(inputs)

  let(:errors) { [] }

  it "stamps depth-0 inputs with access_mode :field, enter_via :hash, consume_alias false" do
    schema = build_schema([
                            input_decl(:a, :array),
                            input_decl(:m, :integer),
                            input_decl(:obj, :field, nil, children: [input_decl(:x, :integer)])
                          ])
    state = State.new
    described_class.new(schema, state).run(errors)
    meta = state.data[:input_metadata]

    expect(errors).to be_empty
    expect(meta[:a][:access_mode]).to eq(:field)
    expect(meta[:a][:enter_via]).to eq(:hash)
    expect(meta[:a][:consume_alias]).to eq(false)

    expect(meta[:m][:access_mode]).to eq(:field)
    expect(meta[:m][:enter_via]).to eq(:hash)
    expect(meta[:m][:consume_alias]).to eq(false)

    # child under object gets field hop and :field access
    expect(meta[:obj][:children][:x][:enter_via]).to eq(:hash)
    expect(meta[:obj][:children][:x][:consume_alias]).to eq(false)
    expect(meta[:obj][:children][:x][:access_mode]).to eq(:field)
  end

  it "errors on nested bare array under object and still stamps field hop defaults" do
    schema = build_schema([
                            input_decl(:root, :field, nil, children: [
                                         input_decl(:nums, :array) # invalid: nested array without declared element
                                       ])
                          ])
    state = State.new
    described_class.new(schema, state).run(errors)
    meta = state.data[:input_metadata]

    expect(errors).not_to be_empty
    expect(meta[:root][:children][:nums][:enter_via]).to eq(:hash)
    expect(meta[:root][:children][:nums][:consume_alias]).to eq(false)
    expect(meta[:root][:children][:nums][:access_mode]).to eq(:field)
  end

  it "array → scalar element (no DSL mode): via :array, consume_alias true, access_mode :element" do
    schema = build_schema([
                            input_decl(:nums, :array, nil, children: [
                                         input_decl(:value, :integer)
                                       ], access_mode: :element)
                          ])
    state = State.new
    described_class.new(schema, state).run(errors)
    ch = state.data[:input_metadata][:nums][:children][:value]

    expect(errors).to be_empty
    expect(ch[:enter_via]).to eq(:array)
    expect(ch[:consume_alias]).to eq(true)
    expect(ch[:access_mode]).to eq(:element)
  end

  it "array → scalar element (DSL mode :element): respects explicit mode" do
    schema = build_schema([
                            input_decl(:nums, :array, nil, children: [
                                         input_decl(:value, :integer)
                                       ], access_mode: :element)
                          ])
    state = State.new
    described_class.new(schema, state).run(errors)
    ch = state.data[:input_metadata][:nums][:children][:value]

    expect(errors).to be_empty
    expect(ch[:enter_via]).to eq(:array)
    expect(ch[:consume_alias]).to eq(true)
    expect(ch[:access_mode]).to eq(:element)
  end

  it "array → declared inner array: via :array, consume_alias true, access_mode :element" do
    schema = build_schema([
                            input_decl(:outer, :array, nil, children: [
                                         input_decl(:inner, :array, nil, children: [
                                                      input_decl(:v, :integer)
                                                    ], access_mode: :element)
                                       ], access_mode: :element)
                          ])
    state = State.new
    described_class.new(schema, state).run(errors)
    ch = state.data[:input_metadata][:outer][:children][:inner]

    expect(errors).to be_empty
    expect(ch[:enter_via]).to eq(:array)
    expect(ch[:consume_alias]).to eq(true)
    expect(ch[:access_mode]).to eq(:element)
  end

  it "array(element object) → inner array field: via :hash, consume_alias false, access_mode :field" do
    schema = build_schema([
                            input_decl(:rows, :array, nil, children: [
                                         input_decl(:id, :integer),
                                         input_decl(:tags, :array, nil, children: [
                                                      input_decl(:tag, :string)
                                                    ], access_mode: :field)
                                       ], access_mode: :field)
                          ])
    state = State.new
    described_class.new(schema, state).run(errors)
    ch = state.data[:input_metadata][:rows][:children][:tags]

    expect(errors).to be_empty
    expect(ch[:enter_via]).to eq(:hash)
    expect(ch[:consume_alias]).to eq(false)
    expect(ch[:access_mode]).to eq(:field)
  end

  it "array → bare inner array reports error" do
    schema = build_schema([
                            input_decl(:outer, :array, nil, children: [
                                         input_decl(:inner, :array) # invalid: no declared element
                                       ])
                          ])
    state = State.new
    described_class.new(schema, state).run(errors)

    expect(errors).not_to be_empty
  end

  it "deep inline arrays mark :element and :array at each inline edge" do
    schema = build_schema([
                            input_decl(:outer, :array, nil, children: [
                                         input_decl(:inner, :array, nil, children: [
                                                      input_decl(:core, :array, nil, children: [
                                                                   input_decl(:x, :integer)
                                                                 ], access_mode: :element)
                                                    ], access_mode: :element)
                                       ], access_mode: :element)
                          ])
    state = State.new
    described_class.new(schema, state).run(errors)
    meta = state.data[:input_metadata]

    expect(errors).to be_empty
    expect(meta[:outer][:children][:inner][:enter_via]).to eq(:array)
    expect(meta[:outer][:children][:inner][:consume_alias]).to eq(true)
    expect(meta[:outer][:children][:inner][:access_mode]).to eq(:element)

    expect(meta[:outer][:children][:inner][:children][:core][:enter_via]).to eq(:array)
    expect(meta[:outer][:children][:inner][:children][:core][:consume_alias]).to eq(true)
    expect(meta[:outer][:children][:inner][:children][:core][:access_mode]).to eq(:element)
  end

  it "invalid DSL: object → scalar child with access_mode :element reports error" do
    schema = build_schema([
                            input_decl(:obj, :field, nil, children: [
                                         input_decl(:x, :integer, nil, access_mode: :element) # illegal context
                                       ])
                          ])
    state = State.new
    described_class.new(schema, state).run(errors)
    expect(errors).not_to be_empty
  end
end

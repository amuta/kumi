# frozen_string_literal: true

require "rspec"
require "tempfile"
require "yaml"

RSpec.describe Kumi::RegistryV2 do
  let(:functions_dir) { create_temp_functions_dir }
  let(:kernels_dir) { create_temp_kernels_dir }
  let(:registry) { described_class.load(functions_dir: functions_dir, kernels_root: kernels_dir) }

  after do
    FileUtils.rm_rf(functions_dir) if functions_dir
    FileUtils.rm_rf(kernels_dir) if kernels_dir
  end

  describe ".load" do
    it "successfully loads functions and kernels" do
      expect(registry).to be_a(Kumi::RegistryV2::Instance)
    end

    it "loads functions from YAML files" do
      expect(registry.resolve_function("core.add")).to eq("core.add")
      expect(registry.function_kind("core.add")).to eq(:elementwise)
    end

    it "loads kernels from target directories" do
      kernel_id = registry.kernel_id_for("core.add", target: :ruby)
      expect(kernel_id).to eq("core.add:ruby:v1")
    end
  end

  describe "function resolution" do
    it "resolves direct function names" do
      expect(registry.resolve_function("core.add")).to eq("core.add")
      expect(registry.resolve_function("agg.sum")).to eq("agg.sum")
    end

    it "resolves function aliases" do
      expect(registry.resolve_function("core.select")).to eq("__select__")
    end

    it "raises error for unknown functions" do
      expect { registry.resolve_function("unknown.func") }.to raise_error(/unknown function/)
    end

    it "handles string and symbol inputs" do
      expect(registry.resolve_function("core.add")).to eq("core.add")
      expect(registry.resolve_function(:"core.add")).to eq("core.add")
    end
  end

  describe "function classification" do
    it "identifies elementwise functions" do
      expect(registry.function_kind("core.add")).to eq(:elementwise)
      expect(registry.function_elementwise?("core.mul")).to be true
      expect(registry.function_elementwise?("agg.sum")).to be false
    end

    it "identifies reduce functions" do
      expect(registry.function_kind("agg.sum")).to eq(:reduce)
      expect(registry.function_reduce?("agg.sum")).to be true
      expect(registry.function_reduce?("core.add")).to be false
    end

    it "identifies select functions via aliases" do
      expect(registry.function_select?("core.select")).to be true
      expect(registry.function_select?("__select__")).to be true
      expect(registry.function_select?("core.add")).to be false
    end
  end

  describe "kernel management" do
    it "maps functions to target-specific kernels" do
      kernel_id = registry.kernel_id_for("core.add", target: :ruby)
      expect(kernel_id).to eq("core.add:ruby:v1")
    end

    it "works with function aliases" do
      kernel_id = registry.kernel_id_for("core.select", target: :ruby)
      expect(kernel_id).to eq("__select__:ruby:v1")
    end

    it "raises error for missing targets" do
      expect { registry.kernel_id_for("core.add", target: :nonexistent) }
        .to raise_error(/no kernel for core\.add on nonexistent/)
    end

    it "retrieves kernel implementations" do
      kernel_id = registry.kernel_id_for("core.add", target: :ruby)
      impl = registry.impl_for(kernel_id)
      expect(impl).to include("a + b")
    end

    it "raises error for unknown kernel IDs" do
      expect { registry.impl_for("nonexistent:kernel:id") }
        .to raise_error(/unknown kernel/)
    end
  end

  describe "reducer identity values" do
    it "provides identity values by dtype" do
      identity = registry.kernel_identity_for("agg.sum", dtype: :integer, target: :ruby)
      expect(identity).to eq(0)

      identity = registry.kernel_identity_for("agg.sum", dtype: :float, target: :ruby)
      expect(identity).to eq(0.0)

      identity = registry.kernel_identity_for("agg.sum", dtype: :string, target: :ruby)
      expect(identity).to eq("")
    end

    it "raises error for non-reducers" do
      expect { registry.kernel_identity_for("core.add", dtype: :integer, target: :ruby) }
        .to raise_error(/no identity/)
    end

    it "raises error for missing dtype" do
      expect { registry.kernel_identity_for("agg.sum", dtype: :boolean, target: :ruby) }
        .to raise_error(/no identity for dtype boolean/)
    end
  end

  describe "registry integrity" do
    it "generates stable fingerprints" do
      ref1 = registry.registry_ref
      ref2 = registry.registry_ref

      expect(ref1).to start_with("sha256:")
      expect(ref1).to eq(ref2)
      expect(ref1.length).to be > 20
    end

    it "includes both functions and kernels in fingerprint" do
      ref = registry.registry_ref
      expect(ref).to be_a(String)
      expect(ref).to match(/\Asha256:[a-f0-9]+\z/)
    end
  end

  private

  def create_temp_functions_dir
    dir = Dir.mktmpdir("kumi_functions")

    # Core functions
    core_dir = File.join(dir, "core")
    Dir.mkdir(core_dir)

    File.write(File.join(core_dir, "math.yaml"), YAML.dump({
                                                             "functions" => [
                                                               {
                                                                 "id" => "core.add",
                                                                 "kind" => "elementwise",
                                                                 "params" => [{ "name" => "a" }, { "name" => "b" }],
                                                                 "dtype" => "same_as(a)"
                                                               },
                                                               {
                                                                 "id" => "core.mul",
                                                                 "kind" => "elementwise",
                                                                 "params" => [{ "name" => "a" }, { "name" => "b" }],
                                                                 "dtype" => "same_as(a)"
                                                               }
                                                             ]
                                                           }))

    File.write(File.join(core_dir, "select.yaml"), YAML.dump({
                                                               "functions" => [
                                                                 {
                                                                   "id" => "__select__",
                                                                   "aliases" => ["core.select"],
                                                                   "kind" => "elementwise",
                                                                   "params" => [
                                                                     { "name" => "condition_mask" },
                                                                     { "name" => "value_when_true" },
                                                                     { "name" => "value_when_false" }
                                                                   ],
                                                                   "dtype" => "same_as(value_when_true)"
                                                                 }
                                                               ]
                                                             }))

    # Aggregate functions
    agg_dir = File.join(dir, "agg")
    Dir.mkdir(agg_dir)

    File.write(File.join(agg_dir, "reducers.yaml"), YAML.dump({
                                                                "functions" => [
                                                                  {
                                                                    "id" => "agg.sum",
                                                                    "kind" => "reduce",
                                                                    "params" => [{ "name" => "values" }],
                                                                    "dtype" => "same_as(values)"
                                                                  },
                                                                  {
                                                                    "id" => "agg.count",
                                                                    "kind" => "reduce",
                                                                    "params" => [{ "name" => "values" }],
                                                                    "dtype" => "integer"
                                                                  }
                                                                ]
                                                              }))

    dir
  end

  def create_temp_kernels_dir
    dir = Dir.mktmpdir("kumi_kernels")

    # Ruby target
    ruby_dir = File.join(dir, "ruby")
    Dir.mkdir(ruby_dir)

    File.write(File.join(ruby_dir, "math.yaml"), YAML.dump({
                                                             "kernels" => [
                                                               {
                                                                 "id" => "core.add:ruby:v1",
                                                                 "fn" => "core.add",
                                                                 "impl" => "->(a, b) { a + b }"
                                                               },
                                                               {
                                                                 "id" => "core.mul:ruby:v1",
                                                                 "fn" => "core.mul",
                                                                 "impl" => "->(a, b) { a * b }"
                                                               }
                                                             ]
                                                           }))

    File.write(File.join(ruby_dir, "select.yaml"), YAML.dump({
                                                               "kernels" => [
                                                                 {
                                                                   "id" => "__select__:ruby:v1",
                                                                   "fn" => "__select__",
                                                                   "impl" => "->(cond, a, b) { cond ? a : b }"
                                                                 }
                                                               ]
                                                             }))

    File.write(File.join(ruby_dir, "reducers.yaml"), YAML.dump({
                                                                 "kernels" => [
                                                                   {
                                                                     "id" => "agg.sum:ruby:v1",
                                                                     "fn" => "agg.sum",
                                                                     "impl" => "->(acc, val) { acc + val }",
                                                                     "identity" => {
                                                                       "integer" => 0,
                                                                       "float" => 0.0,
                                                                       "string" => ""
                                                                     }
                                                                   },
                                                                   {
                                                                     "id" => "agg.count:ruby:v1",
                                                                     "fn" => "agg.count",
                                                                     "impl" => "->(acc, val) { acc + 1 }",
                                                                     "identity" => {
                                                                       "integer" => 0
                                                                     }
                                                                   }
                                                                 ]
                                                               }))

    dir
  end
end

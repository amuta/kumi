# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Codegen::RubyV3::Pipeline::KernelIndex do
  describe ".run" do
    context "kernel implementation extraction with required fields" do
      it "extracts kernel_id → impl mappings using fetch (raises if missing)" do
        pack = {
          "bindings" => {
            "ruby" => {
              "kernels" => [
                { "kernel_id" => "core.add", "impl" => "->(a,b) { a + b }" },
                { "kernel_id" => "core.mul", "impl" => "->(a,b) { a * b }" }
              ]
            }
          }
        }

        result = described_class.run(pack)

        expect(result[:impls]).to eq({
                                       "core.add" => "->(a,b) { a + b }",
                                       "core.mul" => "->(a,b) { a * b }"
                                     })
      end

      it "raises KeyError when kernel_id or impl fields are missing" do
        pack_missing_impl = {
          "bindings" => {
            "ruby" => {
              "kernels" => [{ "kernel_id" => "core.add" }] # Missing "impl"
            }
          }
        }

        expect { described_class.run(pack_missing_impl) }.to raise_error(KeyError, /impl/)
      end
    end

    context "identity value extraction with optional fields" do
      it "extracts identity values using [] access (nil if missing, no error)" do
        pack = {
          "bindings" => {
            "ruby" => {
              "kernels" => [
                { "kernel_id" => "agg.sum", "impl" => "->(a,b) { a + b }", "attrs" => { "identity" => 0 } },
                { "kernel_id" => "agg.mul", "impl" => "->(a,b) { a * b }", "attrs" => { "identity" => 1 } },
                { "kernel_id" => "agg.max", "impl" => "->(a,b) { [a,b].max }" } # No identity
              ]
            }
          }
        }

        result = described_class.run(pack)

        expect(result[:identities]).to eq({
                                            "agg.sum" => 0,
                                            "agg.mul" => 1,
                                            "agg.max" => nil # Missing identity → nil, not error
                                          })
      end
    end

    context "target language parameter and safe extraction" do
      it "uses target parameter to select language bindings" do
        pack = {
          "bindings" => {
            "python" => {
              "kernels" => [{ "kernel_id" => "core.add", "impl" => "lambda a,b: a+b" }]
            },
            "ruby" => {
              "kernels" => [{ "kernel_id" => "core.add", "impl" => "->(a,b) { a + b }" }]
            }
          }
        }

        result = described_class.run(pack, target: "python")

        expect(result[:impls]["core.add"]).to eq("lambda a,b: a+b")
      end

      it "handles missing bindings gracefully with Array() wrapper" do
        pack_no_bindings = {}

        result = described_class.run(pack_no_bindings)

        expect(result[:impls]).to eq({})
        expect(result[:identities]).to eq({})
      end
    end

    context "structured result contract for downstream modules" do
      it "returns {impls:, identities:} structure that StreamLowerer expects" do
        pack = {
          "bindings" => {
            "ruby" => {
              "kernels" => [{ "kernel_id" => "test", "impl" => "test_impl", "attrs" => { "identity" => 42 } }]
            }
          }
        }

        result = described_class.run(pack)

        # StreamLowerer expects these exact keys
        expect(result).to have_key(:impls)
        expect(result).to have_key(:identities)
        expect(result[:impls]).to be_a(Hash)
        expect(result[:identities]).to be_a(Hash)
      end
    end
  end
end

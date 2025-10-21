RSpec.describe Kumi::DocGenerator do
  describe "loading function definitions" do
    it "loads function definitions from YAML" do
      functions_dir = File.join(__dir__, "../../data/functions")
      loader = Kumi::DocGenerator::Loader.new(functions_dir: functions_dir)

      functions = loader.load_functions

      expect(functions).to be_a(Array)
      expect(functions).not_to be_empty

      sum_fn = functions.find { |f| f["id"] == "agg.sum" }
      expect(sum_fn).not_to be_nil
      expect(sum_fn["kind"]).to eq("reduce")
      expect(sum_fn["aliases"]).to include("sum")
    end

    it "loads kernel definitions from YAML" do
      kernels_dir = File.join(__dir__, "../../data/kernels/ruby")
      loader = Kumi::DocGenerator::Loader.new(kernels_dir: kernels_dir)

      kernels = loader.load_kernels

      expect(kernels).to be_a(Array)
      expect(kernels).not_to be_empty

      sum_kernel = kernels.find { |k| k["fn"] == "agg.sum" }
      expect(sum_kernel).not_to be_nil
      expect(sum_kernel["id"]).to eq("agg.sum:ruby:v1")
    end
  end

  describe "merging functions and kernels" do
    it "creates unified doc entries with function and kernel metadata" do
      functions_dir = File.join(__dir__, "../../data/functions")
      kernels_ruby_dir = File.join(__dir__, "../../data/kernels/ruby")

      loader = Kumi::DocGenerator::Loader.new(
        functions_dir: functions_dir,
        kernels_dir: kernels_ruby_dir
      )
      merger = Kumi::DocGenerator::Merger.new(loader)

      docs = merger.merge

      expect(docs).to be_a(Hash)
      expect(docs["sum"]).not_to be_nil

      sum_doc = docs["sum"]
      expect(sum_doc["id"]).to eq("agg.sum")
      expect(sum_doc["kind"]).to eq("reduce")
      expect(sum_doc["kernels"]["ruby"]).to be_a(Hash)
      expect(sum_doc["kernels"]["ruby"]["id"]).to eq("agg.sum:ruby:v1")
    end
  end

  describe "generating JSON for IDE consumption" do
    it "produces IDE-friendly JSON format" do
      functions_dir = File.join(__dir__, "../../data/functions")
      kernels_ruby_dir = File.join(__dir__, "../../data/kernels/ruby")

      loader = Kumi::DocGenerator::Loader.new(
        functions_dir: functions_dir,
        kernels_dir: kernels_ruby_dir
      )
      merger = Kumi::DocGenerator::Merger.new(loader)
      docs = merger.merge

      formatter = Kumi::DocGenerator::Formatters::Json.new(docs)
      json_output = formatter.format

      expect(json_output).to be_a(String)

      parsed = JSON.parse(json_output)
      expect(parsed["sum"]).not_to be_nil
      expect(parsed["sum"]["id"]).to eq("agg.sum")
      expect(parsed["sum"]["arity"]).to eq(1)
    end

    it "handles functions with multiple aliases" do
      functions_dir = File.join(__dir__, "../../data/functions")
      kernels_ruby_dir = File.join(__dir__, "../../data/kernels/ruby")

      loader = Kumi::DocGenerator::Loader.new(
        functions_dir: functions_dir,
        kernels_dir: kernels_ruby_dir
      )
      merger = Kumi::DocGenerator::Merger.new(loader)
      docs = merger.merge

      # subtract has aliases: ["sub", "subtract"]
      expect(docs["sub"]).not_to be_nil
      expect(docs["subtract"]).not_to be_nil
      expect(docs["sub"]["id"]).to eq("core.sub")
      expect(docs["subtract"]["id"]).to eq("core.sub")
    end

    it "correctly extracts arity from params" do
      functions_dir = File.join(__dir__, "../../data/functions")
      kernels_ruby_dir = File.join(__dir__, "../../data/kernels/ruby")

      loader = Kumi::DocGenerator::Loader.new(
        functions_dir: functions_dir,
        kernels_dir: kernels_ruby_dir
      )
      merger = Kumi::DocGenerator::Merger.new(loader)
      docs = merger.merge

      formatter = Kumi::DocGenerator::Formatters::Json.new(docs)
      parsed = JSON.parse(formatter.format)

      # add takes 2 parameters
      expect(parsed["add"]["arity"]).to eq(2)
      # clamp takes 3 parameters
      expect(parsed["clamp"]["arity"]).to eq(3)
    end
  end

  describe "generating Markdown documentation" do
    it "generates readable markdown with function descriptions" do
      functions_dir = File.join(__dir__, "../../data/functions")
      kernels_ruby_dir = File.join(__dir__, "../../data/kernels/ruby")

      loader = Kumi::DocGenerator::Loader.new(
        functions_dir: functions_dir,
        kernels_dir: kernels_ruby_dir
      )
      merger = Kumi::DocGenerator::Merger.new(loader)
      docs = merger.merge

      formatter = Kumi::DocGenerator::Formatters::Markdown.new(docs)
      markdown = formatter.format

      expect(markdown).to include("# Kumi Function Reference")
      expect(markdown).to include("## `agg.sum`")
      expect(markdown).to include("- **Arity:** 1")
      expect(markdown).to include("- **Behavior:** Reduces a dimension `[D] -> T`")
      expect(markdown).to include("### Implementations")
    end

    it "groups functions by ID and lists aliases" do
      functions_dir = File.join(__dir__, "../../data/functions")
      kernels_ruby_dir = File.join(__dir__, "../../data/kernels/ruby")

      loader = Kumi::DocGenerator::Loader.new(
        functions_dir: functions_dir,
        kernels_dir: kernels_ruby_dir
      )
      merger = Kumi::DocGenerator::Merger.new(loader)
      docs = merger.merge

      formatter = Kumi::DocGenerator::Formatters::Markdown.new(docs)
      markdown = formatter.format

      # subtract has multiple aliases
      expect(markdown).to include("## `core.sub`")
      expect(markdown).to match(/Aliases:.*`sub`.*`subtract`/)
    end
  end
end

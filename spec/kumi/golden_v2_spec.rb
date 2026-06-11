# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "tmpdir"

RSpec.describe Kumi::Dev::GoldenV2 do
  let(:io) { StringIO.new }

  describe Kumi::Dev::GoldenV2::Runner do
    around do |example|
      Dir.mktmpdir("golden_v2_spec") do |dir|
        @base_dir = File.join(dir, "golden")
        FileUtils.mkdir_p(File.join(@base_dir, "demo", "expected"))
        File.write(File.join(@base_dir, "demo", "schema.kumi"), "schema do\nend\n")
        example.run
      end
    end

    let(:runner) { described_class.new(base_dir: @base_dir, io: io) }

    it "expands representation groups and explicit names" do
      names = runner.select_representations("frontend,dfir").map(&:name)

      expect(names).to eq(%w[ast input_plan nast snast dfir])
    end

    it "includes loopir in the loop group" do
      names = runner.select_representations("loop").map(&:name)

      expect(names).to eq(%w[loopir])
    end

    it "raises on unknown representations" do
      expect { runner.select_representations("nope") }
        .to raise_error(ArgumentError, /unknown representations: nope/)
    end

    it "verifies only the selected representations" do
      File.write(File.join(@base_dir, "demo", "expected", "ast.txt"), "AST\n")

      allow(Kumi::Dev::PrettyPrinter).to receive(:generate_ast).and_return("AST\n")
      allow(Kumi::Dev::PrettyPrinter).to receive(:generate_dfir)
        .and_raise("dfir should not be generated")

      result = runner.verify(names: ["demo"], reprs: "ast")

      expect(result).to be(true)
      expect(io.string).to include("✓ demo")
    end

    it "verifies loopir when selected" do
      File.write(File.join(@base_dir, "demo", "expected", "loopir.txt"), "LOOP\n")

      allow(Kumi::Dev::PrettyPrinter).to receive(:generate_loopir).and_return("LOOP\n")
      allow(Kumi::Dev::PrettyPrinter).to receive(:generate_ast)
        .and_raise("ast should not be generated")

      result = runner.verify(names: ["demo"], reprs: "loop")

      expect(result).to be(true)
      expect(io.string).to include("✓ demo")
    end

    it "updates only changed selected representations" do
      allow(Kumi::Dev::PrettyPrinter).to receive(:generate_ast).and_return("NEW\n")

      result = runner.update(names: ["demo"], reprs: "ast")

      expect(result).to be(true)
      expect(File.read(File.join(@base_dir, "demo", "expected", "ast.txt"))).to eq("NEW\n")
      expect(io.string).to include("created")
    end
  end
end

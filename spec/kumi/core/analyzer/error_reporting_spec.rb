# frozen_string_literal: true

# Locks in the error-model contract (docs/PASS_AUDIT.md F1/F2): a user-facing
# analyzer error surfaces exactly ONCE, with a real source location, and never
# leaks the internal pass machinery (file paths, "Error in Analysis Pass(...)").
RSpec.describe "analyzer error reporting" do
  def analyze_error(&block)
    ast = Kumi::Core::RubyParser::Dsl.build_syntax_tree(&block)
    begin
      Kumi::Analyzer.analyze!(ast)
      nil
    rescue StandardError => e
      e
    end
  end

  describe "a single type mismatch" do
    subject(:error) do
      analyze_error do
        input do
          string :name
        end
        value :bad, fn(:add, input.name, input.name)
      end
    end

    it "raises a located TypeError" do
      expect(error).to be_a(Kumi::Core::Errors::TypeError)
      expect(error.message).to match(/type mismatch/)
    end

    it "reports the error exactly once" do
      expect(error.message.scan("type mismatch").size).to eq(1)
    end

    it "does not leak internal pass machinery to the user" do
      expect(error.message).not_to include("Error in Analysis Pass")
      expect(error.message).not_to include("nast_dimensional_analyzer_pass.rb")
      expect(error.message).not_to match(%r{lib/kumi/core/analyzer})
    end

    it "carries a real source location, not coordinates in the message text" do
      expect(error.message).to match(/line=\d+|:\d+:/)
    end
  end

  describe "an unknown function" do
    subject(:error) do
      analyze_error do
        input do
          integer :x
        end
        value :v, fn(:no_such_function, input.x)
      end
    end

    it "reports a located error naming the function, with no internal leak" do
      expect(error).to be_a(Kumi::Core::Errors::SemanticError)
      expect(error.message).to include("unknown function `no_such_function`")
      expect(error.message).not_to include("Error in Analysis Pass")
      expect(error.message).not_to include("registry_v2.rb")
      expect(error.message).to match(/line=\d+|:\d+:/)
    end
  end

  describe "cross/outer argument validation" do
    it "reports a located error for cross on a scalar, with no leak" do
      error = analyze_error do
        input do
          integer :x
        end
        value :c, cross(input.x)
      end

      expect(error).to be_a(Kumi::Core::Errors::SemanticError)
      expect(error.message).to include("cross requires an array argument")
      expect(error.message.scan("cross requires an array argument").size).to eq(1)
      expect(error.message).not_to include("Error in Analysis Pass")
    end
  end

  describe "CompilerBug" do
    it "frames internal invariants as a bug to report, distinct from user errors" do
      bug = Kumi::Core::Errors::CompilerBug.new("widget axis desync")

      expect(bug).to be_a(Kumi::Core::Errors::Error)
      expect(bug).not_to be_a(Kumi::Core::Errors::LocatedError)
      expect(bug.message).to include("internal compiler error (please report)")
      expect(bug.message).to include("widget axis desync")
    end
  end

  describe "UnsupportedFeature" do
    it "names a missing backend capability, distinct from a bug and from a user error" do
      feat = Kumi::Core::Errors::UnsupportedFeature.new("JS loop codegen does not support opcode :foo")

      expect(feat).to be_a(Kumi::Core::Errors::Error)
      expect(feat).not_to be_a(Kumi::Core::Errors::CompilerBug)
      expect(feat).not_to be_a(Kumi::Core::Errors::LocatedError)
    end
  end
end

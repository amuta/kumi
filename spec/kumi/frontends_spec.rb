# frozen_string_literal: true

RSpec.describe Kumi::Frontends do
  let(:temp_dir) { Dir.mktmpdir("frontends_test") }

  around do |example|
    original_parser = ENV.fetch("KUMI_PARSER", nil)
    example.run
    ENV["KUMI_PARSER"] = original_parser
    FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
  end

  describe ".load" do
    context "with Ruby frontend" do
      let(:ruby_file) { File.join(temp_dir, "test.rb") }

      before do
        File.write(ruby_file, <<~RUBY)
          schema do
            input do
              integer :x
              integer :y
            end
          #{'  '}
            value :sum, input.x + input.y
          end
        RUBY
      end

      it "loads Ruby schema files" do
        ENV["KUMI_PARSER"] = "ruby"
        schema, inputs = described_class.load(path: ruby_file)

        expect(schema).to be_a(Kumi::Syntax::Root)
        expect(inputs).to eq({})
      end

      it "auto-detects .rb files" do
        ENV["KUMI_PARSER"] = "auto"
        schema, = described_class.load(path: ruby_file)

        expect(schema).to be_a(Kumi::Syntax::Root)
      end
    end

    context "with Text frontend" do
      let(:kumi_file) { File.join(temp_dir, "test.kumi") }

      before do
        File.write(kumi_file, <<~KUMI)
          schema do
            input do
              integer :x
              integer :y
            end
          #{'  '}
            value :sum, input.x + input.y
          end
        KUMI
      end

      it "attempts to load .kumi files with kumi-parser" do
        ENV["KUMI_PARSER"] = "text"

        schema, inputs = described_class.load(path: kumi_file)
        expect(schema).to be_a(Kumi::Syntax::Root)
        expect(inputs).to eq({})
      end

      it "auto-detects .kumi files" do
        ENV["KUMI_PARSER"] = "auto"

        schema, inputs = described_class.load(path: kumi_file)
        expect(schema).to be_a(Kumi::Syntax::Root)
        expect(inputs).to eq({})
      end
    end

    context "with auto mode" do
      let(:base_path) { File.join(temp_dir, "test") }
      let(:ruby_file) { "#{base_path}.rb" }
      let(:kumi_file) { "#{base_path}.kumi" }

      before do
        File.write(ruby_file, <<~RUBY)
          schema do
            input do
              integer :x
            end
            value :result, input.x
          end
        RUBY
      end

      it "prefers .kumi over .rb when both exist" do
        File.write(kumi_file, "# kumi content")
        ENV["KUMI_PARSER"] = "auto"

        # Parser error when trying to parse .kumi file
        expect do
          described_class.load(path: ruby_file)
        end.to raise_error(StandardError)
      end

      it "falls back to .rb when .kumi doesn't exist" do
        ENV["KUMI_PARSER"] = "auto"
        schema, = described_class.load(path: ruby_file)

        expect(schema).to be_a(Kumi::Syntax::Root)
      end
    end

    context "equivalence between Ruby and Text frontends" do
      let(:schema_content) do
        <<~SCHEMA
          schema do
            input do
              integer :x
              integer :y
            end
          #{'  '}
            value :sum, input.x + input.y
            trait :positive_sum, sum > 0
          end
        SCHEMA
      end

      it "produces equivalent AST from .rb and .kumi files" do
        ruby_file = File.join(temp_dir, "equiv.rb")
        kumi_file = File.join(temp_dir, "equiv.kumi")

        File.write(ruby_file, schema_content)
        File.write(kumi_file, schema_content)

        ruby_schema, = Kumi::Frontends::Ruby.load(path: ruby_file)
        text_schema, = Kumi::Frontends::Text.load(path: kumi_file)

        expect(text_schema).to eq(ruby_schema)
      end
    end
  end
end

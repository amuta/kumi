# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"

# Pins the cross-target semantics contract (docs/CROSS_TARGET_SEMANTICS.md):
# the handful of operations where Ruby and JS would otherwise diverge must
# produce identical results. Each case runs the compiled Ruby AND executes the
# generated JavaScript (requires `node`) over the same inputs.
RSpec.describe "cross-target semantics (Ruby == JS)" do
  def js_eval(schema, output, input)
    Dir.mktmpdir("xtarget") do |dir|
      path = File.join(dir, "s.mjs")
      schema.write_source(path, platform: :javascript)
      runner = File.join(dir, "r.mjs")
      File.write(runner, <<~JS)
        import * as M from #{path.inspect};
        const out = M._#{output}(#{JSON.generate(input)});
        // Encode so NaN/Infinity survive (JSON would turn them into null).
        process.stdout.write(typeof out === "number" && !Number.isFinite(out) ? String(out) : JSON.stringify(out));
      JS
      raw = `node #{runner}`
      case raw
      when "NaN" then Float::NAN
      when "Infinity" then Float::INFINITY
      when "-Infinity" then -Float::INFINITY
      else JSON.parse(raw)
      end
    end
  end

  def expect_parity(schema, output, input, expected)
    ruby = schema.from(input)[output]
    js = js_eval(schema, output, input)
    if expected.respond_to?(:nan?) && expected.nan?
      expect(ruby).to be_nan
      expect(js).to be_nan
    else
      expect(ruby).to eq(expected)
      expect(js).to eq(expected)
    end
  end

  describe "to_string of a float keeps the .0" do
    let(:schema) do
      Class.new do
        extend Kumi::Schema

        schema do
          input { float :x }
          value :s, fn(:to_string, input.x)
        end
      end
    end

    {
      3.0 => "3.0",
      100.0 => "100.0",
      3.5 => "3.5",
      -0.0 => "-0.0",
      1e21 => "1.0e+21",
      1e-7 => "1.0e-07"
    }.each do |value, str|
      it "to_string(#{value}) == #{str.inspect} on both targets" do
        expect_parity(schema, :s, { x: value }, str)
      end
    end
  end

  describe "to_integer / to_float of a string use Ruby parsing" do
    let(:int_schema) do
      Class.new do
        extend Kumi::Schema

        schema do
          input { string :s }
          value :n, fn(:to_integer, input.s)
        end
      end
    end
    let(:float_schema) do
      Class.new do
        extend Kumi::Schema

        schema do
          input { string :s }
          value :f, fn(:to_float, input.s)
        end
      end
    end

    { "abc" => 0, "" => 0, "0x1f" => 0, "12abc" => 12, "10" => 10 }.each do |str, n|
      it "to_integer(#{str.inspect}) == #{n} on both targets" do
        expect_parity(int_schema, :n, { s: str }, n)
      end
    end

    { "abc" => 0.0, "3.14" => 3.14, "1e3" => 1000.0 }.each do |str, f|
      it "to_float(#{str.inspect}) == #{f} on both targets" do
        expect_parity(float_schema, :f, { s: str }, f)
      end
    end
  end

  describe "pow of a negative base with a fractional exponent is NaN, not Complex" do
    let(:schema) do
      Class.new do
        extend Kumi::Schema

        schema do
          input do
            float :a
            float :b
          end
          value :r, input.a**input.b
        end
      end
    end

    it "(-8.0) ** (1/3) is NaN on both targets (Ruby would give a Complex)" do
      expect_parity(schema, :r, { a: -8.0, b: 1.0 / 3 }, Float::NAN)
    end

    it "still computes ordinary powers" do
      expect_parity(schema, :r, { a: 2.0, b: 0.5 }, Math.sqrt(2))
      expect_parity(schema, :r, { a: 2.0, b: -1.0 }, 0.5)
    end
  end
end

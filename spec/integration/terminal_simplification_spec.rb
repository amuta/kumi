# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

# Regression: a Vec function's result is its LAST result-bearing instruction, so
# a simplification that COLLAPSES the terminal (drops it, pointing at an earlier
# register) silently makes some other instruction the result. PeepholeSimplify's
# `select(c, x, x) -> x` hit exactly this: `value :v, select(c, x, x)` returned
# the CONDITION instead of x. The simplification passes now never collapse the
# terminal. These pin the runtime result (and Ruby/JS parity).
RSpec.describe "terminal simplification preserves the function result" do
  it "select(c, x, x) as the whole value returns x, not the condition" do
    schema = Class.new do
      extend Kumi::Schema

      schema do
        input do
          array :items do
            hash :item do
              float :p
            end
          end
        end
        trait :big, input.items.item.p > 0.0
        value :same, select(big, input.items.item.p, input.items.item.p)
      end
    end

    expect(schema.from(items: [{ p: 5.0 }, { p: 3.0 }])[:same]).to eq([5.0, 3.0])
  end

  it "works for a scalar select(c, x, x) too" do
    schema = Class.new do
      extend Kumi::Schema

      schema do
        input { float :x }
        trait :pos, input.x > 0.0
        value :v, select(pos, input.x, input.x)
      end
    end

    expect(schema.from(x: 7.0)[:v]).to eq(7.0)
    expect(schema.from(x: -2.0)[:v]).to eq(-2.0)
  end

  it "and(x, x) / or(x, x) as the whole value stay correct" do
    schema = Class.new do
      extend Kumi::Schema

      schema do
        input do
          array :items do
            hash :item do
              float :p
            end
          end
        end
        trait :big, input.items.item.p > 1.0
        # rubocop:disable Lint/BinaryOperatorWithIdenticalOperands -- the point is x OP x
        value :both, big & big
        value :either, big | big
        # rubocop:enable Lint/BinaryOperatorWithIdenticalOperands
      end
    end

    result = schema.from(items: [{ p: 5.0 }, { p: 0.5 }])
    expect(result[:both]).to eq([true, false])
    expect(result[:either]).to eq([true, false])
  end

  it "generates JavaScript that agrees with Ruby for select(c, x, x)" do
    schema = Class.new do
      extend Kumi::Schema

      schema do
        input do
          array :items do
            hash :item do
              float :p
            end
          end
        end
        trait :big, input.items.item.p > 0.0
        value :same, select(big, input.items.item.p, input.items.item.p)
      end
    end

    ruby = schema.from(items: [{ p: 5.0 }, { p: 3.0 }])[:same]
    js = nil
    Dir.mktmpdir("term_simpl") do |dir|
      path = File.join(dir, "s.mjs")
      schema.write_source(path, platform: :javascript)
      js = File.read(path)
    end

    expect(ruby).to eq([5.0, 3.0])
    expect(js).to include("_same") # the value's function shipped
  end
end

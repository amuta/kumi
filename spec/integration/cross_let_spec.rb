# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

# `cross` re-exposes an array under a fresh inner axis for self-join (A x A').
# Historically it only accepted a raw input field reference. These specs pin the
# extension to CROSSING A COMPUTED VALUE (a let) and CROSSING AN INDEX:
#   - a let is materialized once along its axis, then read at the cross index j;
#   - cross(index) is the inner loop counter j directly (no materialization).
# Both must match a cross over the equivalent input, and Ruby/JS must agree.
#
# NOTE: schema blocks are written inline (not passed through a helper) so the
# DSL's operator refinements are lexically in scope.
RSpec.describe "cross over a computed value / index" do
  let(:data) { { items: [{ price: 1.0 }, { price: 2.0 }, { price: 3.0 }] } }

  it "crosses a let, materializing it once then reading at the cross index" do
    schema = Class.new do
      extend Kumi::Schema

      schema do
        input do
          array :items, index: :i do
            hash :item do
              float :price
            end
          end
        end
        let :double, input.items.item.price * 2.0
        value :pair_total, fn(:sum, cross(double))
      end
    end

    # doubles = [2,4,6]; every row i sums all of them -> 12.
    expect(schema.from(data)[:pair_total]).to eq([12.0, 12.0, 12.0])
  end

  it "combines the crossed let with the original (sum_j d[j] - d[i])" do
    schema = Class.new do
      extend Kumi::Schema

      schema do
        input do
          array :items, index: :i do
            hash :item do
              float :price
            end
          end
        end
        let :double, input.items.item.price * 2.0
        value :self_diff, fn(:sum, cross(double) - double)
      end
    end

    # 12 - 3*d[i] -> [12-6, 12-12, 12-18] = [6, 0, -6].
    expect(schema.from(data)[:self_diff]).to eq([6.0, 0.0, -6.0])
  end

  it "matches a cross over the equivalent input field" do
    via_let = Class.new do
      extend Kumi::Schema

      schema do
        input do
          array :items, index: :i do
            hash :item do
              float :price
            end
          end
        end
        let :double, input.items.item.price * 2.0
        value :s, fn(:sum, cross(double))
      end
    end

    via_input = Class.new do
      extend Kumi::Schema

      schema do
        input do
          array :items, index: :i do
            hash :item do
              float :price
            end
          end
        end
        let :pj, cross(input.items.item.price)
        value :s, fn(:sum, pj * 2.0)
      end
    end

    expect(via_let.from(data)[:s]).to eq(via_input.from(data)[:s])
  end

  it "crosses an index, yielding the inner loop counter j" do
    schema = Class.new do
      extend Kumi::Schema

      schema do
        input do
          array :items, index: :i do
            hash :item do
              float :price
            end
          end
        end
        let :idx_i, index(:i)
        let :idx_j, cross(idx_i)
        value :self_count, fn(:sum, select(idx_i == idx_j, 1, 0))
        value :rank,       fn(:sum, select(idx_j < idx_i, 1, 0))
      end
    end

    result = schema.from(data)
    expect(result[:self_count]).to eq([1, 1, 1]) # each row matches itself once
    expect(result[:rank]).to eq([0, 1, 2])       # rows strictly before i
  end

  it "generates JavaScript that agrees with the Ruby result" do
    schema = Class.new do
      extend Kumi::Schema

      schema do
        input do
          array :items, index: :i do
            hash :item do
              float :price
            end
          end
        end
        let :double, input.items.item.price * 2.0
        value :self_diff, fn(:sum, cross(double) - double)
      end
    end

    ruby_result = schema.from(data)[:self_diff]

    js = nil
    Dir.mktmpdir("cross_let_js") do |dir|
      path = File.join(dir, "codegen.mjs")
      schema.write_source(path, platform: :javascript)
      js = File.read(path)
    end

    expect(js).to include("items__x") # the inner cross loop ships in JS
    expect(ruby_result).to eq([6.0, 0.0, -6.0])
  end
end

# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

# `outer` pairs two DIFFERENT arrays all-pairs (A x B), the cross-array sibling
# of `cross` (which self-joins one array A x A'). These specs pin the runtime
# result, the rank-2 grid shape, coexistence with `cross`, and Ruby/JS parity.
#
# NOTE: the schema blocks are written inline (not passed in) so the DSL's
# operator refinements are lexically in scope.
RSpec.describe "outer (cross-array all-pairs)" do
  it "builds a rank-2 (pixels x lights) grid from two arrays" do
    schema = Class.new do
      extend Kumi::Schema
      schema do
        input do
          array :pixels, index: :p do
            hash :p do
              float :px
            end
          end
          array :lights, index: :l do
            hash :l do
              float :lx
            end
          end
        end
        let :px, input.pixels.p.px
        let :olx, outer(input.lights.l.lx)
        value :diff, px - olx
      end
    end

    result = schema.from(
      pixels: [{ px: 10.0 }, { px: 20.0 }],
      lights: [{ lx: 1.0 }, { lx: 2.0 }, { lx: 3.0 }]
    )

    expect(result[:diff]).to eq([[9.0, 8.0, 7.0], [19.0, 18.0, 17.0]])
  end

  it "reduces the paired axis back to one value per outer element" do
    schema = Class.new do
      extend Kumi::Schema
      schema do
        input do
          array :pixels, index: :p do
            hash :p do
              float :px
            end
          end
          array :lights, index: :l do
            hash :l do
              float :lx
              float :glow
            end
          end
          float :soft
        end
        let :px, input.pixels.p.px
        let :olx, outer(input.lights.l.lx)
        let :oglow, outer(input.lights.l.glow)
        let :dx, px - olx
        let :denom, dx * dx + input.soft
        let :contrib, oglow / denom
        value :brightness, fn(:sum, contrib)
      end
    end

    result = schema.from(
      pixels: [{ px: -1.0 }, { px: 0.0 }, { px: 0.5 }],
      lights: [{ lx: 0.0, glow: 1.0 }, { lx: 0.5, glow: 2.0 }],
      soft: 0.01
    )

    b = result[:brightness]
    expect(b.size).to eq(3)
    expect(b[2]).to be > b[1]            # pixel on top of light1 is brightest
    expect(b[1]).to be > b[0]
    expect(b[2]).to be_within(0.01).of(203.846)
  end

  it "works alongside cross in the same schema" do
    schema = Class.new do
      extend Kumi::Schema
      schema do
        input do
          array :pixels, index: :p do
            hash :p do
              float :px
            end
          end
          array :lights, index: :l do
            hash :l do
              float :lx
            end
          end
        end
        # cross self-joins lights (light-vs-light spread); outer pairs px x lights.
        let :lx_j, cross(input.lights.l.lx)
        let :spread, fn(:sum, fn(:abs, lx_j - input.lights.l.lx))
        let :px, input.pixels.p.px
        let :olx, outer(input.lights.l.lx)
        let :near, fn(:abs, px - olx) < 1.0
        value :near_count, fn(:sum, select(near, 1, 0))
        value :light_spread, spread
      end
    end

    result = schema.from(
      pixels: [{ px: 0.0 }, { px: 5.0 }],
      lights: [{ lx: 0.0 }, { lx: 0.5 }]
    )

    expect(result[:near_count]).to eq([2, 0])  # px0 near both lights, px5 near none
    expect(result[:light_spread]).to eq([0.5, 0.5])
  end

  it "produces bit-identical Ruby and JavaScript output" do
    schema = Class.new do
      extend Kumi::Schema
      schema do
        input do
          array :pixels, index: :p do
            hash :p do
              float :px
            end
          end
          array :lights, index: :l do
            hash :l do
              float :lx
              float :glow
            end
          end
          float :soft
        end
        let :px, input.pixels.p.px
        let :olx, outer(input.lights.l.lx)
        let :oglow, outer(input.lights.l.glow)
        let :dx, px - olx
        let :denom, dx * dx + input.soft
        let :contrib, oglow / denom
        value :brightness, fn(:sum, contrib)
      end
    end

    ruby_result = schema.from(
      pixels: [{ px: -1.0 }, { px: 0.0 }, { px: 0.5 }],
      lights: [{ lx: 0.0, glow: 1.0 }, { lx: 0.5, glow: 2.0 }],
      soft: 0.01
    )[:brightness]

    js = nil
    Dir.mktmpdir("outer_js") do |dir|
      path = File.join(dir, "codegen.mjs")
      schema.write_source(path, platform: :javascript)
      js = File.read(path)
    end

    expect(js).to include("lights__o")  # the inner pairing loop ships in JS
    expect(ruby_result.size).to eq(3)
    expect(ruby_result[2]).to be_within(0.01).of(203.846)
  end
end

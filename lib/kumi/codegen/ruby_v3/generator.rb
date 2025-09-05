# frozen_string_literal: true

# Zeitwerk: Kumi::Codegen::RubyV3::Generator

module Kumi
  module Codegen
    module RubyV3
      class Generator
        def initialize(pack, module_name:)
          @pack = pack
          @module_name = module_name
        end

        def render
          Kumi::Codegen::RubyV3::Pipeline::PackSanity.run(@pack)
          view = Kumi::Codegen::RubyV3::Pipeline::PackView.new(@pack)
          kernels_info = Kumi::Codegen::RubyV3::Pipeline::KernelIndex.run(@pack, target: "ruby")
          kernels = kernels_info[:impls]
          identities = kernels_info[:identities]

          # Cache for producer operations (topo sorted guarantees producers come first)
          producer_cache = {}

          fns = view.declarations_in_order.map do |name|
            ctx = Kumi::Codegen::RubyV3::Pipeline::DeclContext.run(view, name)
            rank = ctx[:axes].length
            consts = Kumi::Codegen::RubyV3::Pipeline::ConstPlan.run(ctx)
            deps = Kumi::Codegen::RubyV3::Pipeline::DepPlan.run(view, ctx)

            # Cache this declaration's operations BEFORE calling StreamLowerer
            # so that subsequent declarations can inline this one
            producer_cache[name] = { ctx:, consts:, deps: }

            fn = Kumi::Codegen::RubyV3::Pipeline::StreamLowerer.run(view, ctx, consts:, deps:, identities:, producer_cache:)

            fn
          end

          Kumi::Codegen::RubyV3::RubyRenderer.render(program: fns, module_name: @module_name, pack_hash: pack_hash(@pack),
                                                     kernels_table: kernels)
        end

        private

        def pack_hash(pack)
          (pack["hashes"] || {}).values.join(":")
        end
      end
    end
  end
end

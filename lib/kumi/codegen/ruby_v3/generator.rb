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
          kernels      = kernels_info[:impls]
          identities   = kernels_info[:identities]

          producer_cache = {}

          binding.pry

          fns = view.declarations_in_order.map do |name|
            ctx     = Kumi::Codegen::RubyV3::Pipeline::DeclContext.run(view, name)
            consts  = Kumi::Codegen::RubyV3::Pipeline::ConstPlan.run(ctx)
            deps    = Kumi::Codegen::RubyV3::Pipeline::DepPlan.run(view, ctx)

            # Normalize reduce plans: array ("reduce_plans") -> map (:reduce_plans_by_id)
            unless ctx.key?(:reduce_plans_by_id)
              plans = Array(ctx[:reduce_plans])
              rp_map = {}
              plans.each do |rp|
                # tolerate symbol or string keys from PackView
                get = ->(k) { rp[k] || rp[k.to_s] }
                id = get.call(:op_id)
                next unless id
                rp_map[id] = rp
              end
              ctx = ctx.merge(reduce_plans_by_id: rp_map)
            end

            producer_cache[name] = { ctx: ctx, consts: consts, deps: deps }

            Kumi::Codegen::RubyV3::Pipeline::StreamLowerer.run(
              view, ctx,
              consts: consts,
              deps: deps,
              identities: identities,
              producer_cache: producer_cache
            )
          end

          Kumi::Codegen::RubyV3::RubyRenderer.render(
            program: fns,
            module_name: @module_name,
            pack_hash: pack_hash(@pack),
            kernels_table: kernels
          )
        end

        private

        def pack_hash(pack)
          (pack["hashes"] || {}).values.join(":")
        end
      end
    end
  end
end

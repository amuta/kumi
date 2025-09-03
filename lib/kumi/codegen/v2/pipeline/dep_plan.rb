# frozen_string_literal: true

require "set"

module Kumi
  module Codegen
    module V2
      module Pipeline
        module DepPlan
          module_function
          def run(ctx, producer_axes:)
            inline_ids = Set.new
            indexed = {}
            ctx[:ops].select { |o| o["op"] == "LoadDeclaration" }.each do |op|
              id = op["id"]; target = Array(op["args"]).first.to_s
              if ctx[:inline].dig("op_#{id}", "decision") == "inline"
                inline_ids << id
              else
                prod_rank = producer_axes.call(target).length
                cons_rank = ctx[:axes].length
                raise "consumer has fewer axes than producer" if cons_rank < prod_rank
                indexed[id] = { name: target, rank: prod_rank }
              end
            end
            { inline_ids:, indexed: }
          end
        end
      end
    end
  end
end
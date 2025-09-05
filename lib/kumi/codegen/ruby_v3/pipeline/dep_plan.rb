# frozen_string_literal: true

# Zeitwerk: Kumi::Codegen::RubyV3::Pipeline::DepPlan

require "set"

module Kumi
  module Codegen
    module RubyV3
      module Pipeline
        module DepPlan
          module_function

          def run(view, ctx)
            inline_ids = Set.new
            indexed = {}
            ctx[:ops].select { _1["op"] == "LoadDeclaration" }.each do |op|
              id = op["id"]
              name = op["args"].first.to_s
              if ctx[:inline].dig("op_#{id}", "decision") == "inline"
                inline_ids << id
              else
                indexed[id] = { name:, rank: view.producer_axes(name).length }
              end
            end
            { inline_ids:, indexed:, inlined_vars: {} }
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

# Zeitwerk: Kumi::Codegen::RubyV3::Pipeline::ConstPlan

require "set"

module Kumi
  module Codegen
    module RubyV3
      module Pipeline
        module ConstPlan
          module_function

          def run(ctx)
            inline_ids = Set.new
            prelude = []

            hoisted_const_ids = Set.new(
              ctx[:site_schedule]["hoisted_scalars"]
                .select { |h| h["kind"] == "const" }
                .map { |h| h["id"] }
            )

            ctx[:ops].select { |o| o["op"] == "Const" }.each do |op|
              id = op["id"]
              val = op["args"].first

              if hoisted_const_ids.include?(id)
                prelude << { name: "c#{id}", value: val }
              else
                inline_ids << id
              end
            end

            { inline_ids:, prelude: }
          end
        end
      end
    end
  end
end

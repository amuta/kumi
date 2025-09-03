# frozen_string_literal: true

require "set"

module Kumi
  module Codegen
    module V2
      module Pipeline
        module ConstPlan
          module_function
          def run(ctx)
            uses = Hash.new(0)
            ctx[:ops].each do |op|
              Array(op["args"]).each { |ref| uses[ref] += 1 if ref.is_a?(Integer) }
            end
            inline, prelude = Set.new, []
            ctx[:ops].select { |o| o["op"] == "Const" }.each do |op|
              id = op["id"]; val = Array(op["args"]).first
              if uses[id] <= 1
                inline << id
              else
                prelude << { name: "c#{id}", value: val }
              end
            end
            { inline_ids: inline, prelude: prelude }
          end
        end
      end
    end
  end
end
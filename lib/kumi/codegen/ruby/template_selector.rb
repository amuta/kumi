# frozen_string_literal: true

module Kumi
  module Codegen
    class Ruby
      class TemplateSelector
        def select_template(op_plan, ops_by_id = {}, _ = nil)
          case op_plan[:op_type]
          when "Const"           then :const_scalar
          when "LoadInput"       then :load_input
          when "Reduce"          then :reduce_last
          when "ConstructTuple"  then :construct_tuple
          when "LoadDeclaration" then :load_declaration
          when "Select"
            r = op_plan[:stamp]["axes"]
            r.empty? ? :select_scalar : :select_vector
          when "Map"
            r = op_plan[:stamp]["axes"]
            r.empty? ? :map_scalar : :map_nary
          else
            raise "Unknown operation type: #{op_plan[:op_type]}"
          end
        end
      end
    end
  end
end

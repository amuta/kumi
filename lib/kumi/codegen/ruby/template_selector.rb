# frozen_string_literal: true

module Kumi
  module Codegen
    class RubyV2
      class TemplateSelector
        def select_template(op_plan)
          case op_plan[:op_type]
          when "Const"           then :const_scalar
          when "LoadInput"       then :load_input # scalar or vector; accessor returns shape
          when "AlignTo"         then :align_to_noop
          when "Map"             then :map_generic
          when "Select"          then :select_generic
          when "Reduce"          then :reduce_last
          when "ConstructTuple"  then :construct_tuple
          when "LoadDeclaration" then :load_declaration
          else
            raise "Unknown operation type: #{op_plan[:op_type]}"
          end
        end
      end
    end
  end
end

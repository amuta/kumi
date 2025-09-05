# frozen_string_literal: true

module Kumi
  module Codegen
    module RubyV2
      module NameMangler
        module_function

        def sanitize_const(s)  = s.to_s.gsub(/[^a-zA-Z0-9]+/, "_").gsub(/^\d+/, "_").upcase
        def sanitize_method(s) = s.to_s.gsub(/[^a-zA-Z0-9]+/, "_").gsub(/^\d+/, "_").downcase

        def chain_const_for(input_name) = "CHAIN_#{sanitize_const(input_name)}"

        def eval_method_for(decl_name)  = "_eval_#{sanitize_method(decl_name)}"

        def tmp_for_op(op_id, ns: nil)
          ns ? "inl_#{sanitize_method(ns)}_v#{op_id}" : "v#{op_id}"
        end

        def axis_var(axis_token)        = "a_#{sanitize_method(axis_token)}"

        def row_var_for_depth(d)        = "row_#{d}"
      end
    end
  end
end

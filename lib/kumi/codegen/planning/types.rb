# frozen_string_literal: true

module Kumi
  module Codegen
    module Planning
      # -----------------------------
      # IR-facing, typed-ish structs
      # -----------------------------

      # One input path from analysis.input_table
      InputSpec = Struct.new(
        :path_fqn,        # Array<String|Symbol>   e.g. ["cube","layer"]
        :navigation_steps,  # Array<Hash>           e.g. [{axis: :cube, path: ["cube"], loop_idx: 0}]
        :axes,
        keyword_init: true
      )

      # One op inside a declaration
      OpSpec = Struct.new(
        :id,          # Integer
        :kind,        # Symbol   :load_input, :load_declaration, :map, :select, :const, :reduce
        :args,        # Array    op-specific
        :stamp_axes,  # Array<Symbol> (ordered, prefix of decl axes)
        :dtype,       # Symbol   :float, :integer, :boolean, etc
        :attrs,       # Hash     e.g. { fn: "core.mul" } or { axis: :items, fn: "agg.sum" }
        keyword_init: true
      )

      # One declaration
      DeclSpec = Struct.new(
        :name,        # Symbol
        :axes,        # Array<Symbol> in loop order, e.g. [:items]
        :parameters,  # Array<Hash> (raw from IR, {kind:, path:} or {kind: :dependency, source:})
        :ops,         # Array<OpSpec>
        :result_id,   # Integer
        keyword_init: true
      )

      # Whole module IR view we need for planning
      ModuleSpec = Struct.new(
        :version,     # String
        :modname,     # String
        :decls,       # Hash{Symbol => DeclSpec}
        :inputs,      # Array<InputSpec>
        :defaults,    # Hash {:key_policy,:on_missing}
        keyword_init: true
      )
    end
  end
end

# frozen_string_literal: true

module Kumi
  # The algebra of a compiled schema, as read-only data.
  #
  # A Kumi schema is, formally: a set of typed, domain-constrained **inputs**
  # (free variables), a set of **definitions** (values and traits) each given by
  # an expression over inputs and earlier definitions, and the **dependency
  # relation** between them. `SchemaMetadata` exposes exactly that — precise,
  # named, and total — sourced from the analyzer rather than re-derived.
  #
  # Returned by `MySchema.schema_metadata`. It is the surface every tool over
  # Kumi builds on (form generation, simulation harnesses, fuzzers, docs) and the
  # self-describing contract an LLM reads to reason about a schema it cannot see
  # the source of. See {#to_h} for the serializable form and {#to_s}/{Printer}
  # for the human/LLM-readable rendering.
  class SchemaMetadata
    # One input leaf: a typed, optionally domain-bounded free variable.
    InputField = Struct.new(:path, :type, :domain, :axes, :element_path, keyword_init: true) do
      # Dotted address, e.g. "scenarios.scenario.claiming_age".
      def address = path.join(".")

      # Whether the leaf lives inside one or more arrays.
      def in_array = !axes.empty?

      def to_h
        h = { path: path, address: address, type: type, axes: axes, element_path: element_path }
        h[:domain] = domain.to_s if domain
        h
      end
    end

    # One definition: a named value or trait given by an expression over inputs
    # and earlier definitions.
    Definition = Struct.new(:name, :kind, :type, :axes, :expression, :reads, :read_by, keyword_init: true) do
      def scalar? = axes.empty?
      def vector? = !axes.empty?

      def to_h
        {
          name: name, kind: kind, type: type, axes: axes,
          expression: expression, reads: reads, read_by: read_by
        }
      end
    end

    def initialize(state, syntax_tree)
      @state = state
      @syntax_tree = syntax_tree
    end

    # ---- inputs: the free variables -----------------------------------------

    # Recursive description of the declared inputs.
    # Shape: `{ name => { type:, ... } }`; array entries carry an `element`,
    # object entries carry `fields`.
    #
    # @return [Hash{Symbol => Hash}]
    def inputs
      @state[:input_form_schema] || {}
    end

    # @return [Array<Symbol>] top-level input names
    def input_names
      inputs.keys
    end

    # Flat list of every input *leaf*, each an {InputField}: its addressable
    # path, dtype, declared domain, the array axes it sits under, and the key
    # path into one array element. Navigation (`axes`, `element_path`) is taken
    # from the analyzer's `precomputed_plan_by_fqn`, not re-derived, so it is
    # correct through arbitrary nesting and multiple arrays.
    #
    # @return [Array<InputField>]
    def input_fields
      @input_fields ||= begin
        leaves = []
        walk_input_nodes(@state[:input_metadata] || {}, [], leaves)
        plans = @state[:precomputed_plan_by_fqn] || {}
        leaves.map { |leaf| build_input_field(leaf, plans) }
      end
    end

    # Look up one input leaf by path (array of symbols or dotted string).
    #
    # @return [InputField, nil]
    def input_field(path)
      key = path.is_a?(String) ? path.split(".").map(&:to_sym) : Array(path)
      input_fields.find { |f| f.path == key }
    end

    # Nested tree mirroring the declared structure with domains attached.
    #
    # @return [Hash]
    def input_tree
      (@state[:input_metadata] || {}).transform_values { |node| node_to_tree(node) }
    end

    # The raw per-path input navigation plan keyed by dotted path. Authoritative
    # source for axis/element information; most callers want {#input_fields}.
    #
    # @return [Hash{String => Hash}]
    def input_plan
      @state[:precomputed_plan_by_fqn] || {}
    end

    # ---- definitions: values and traits -------------------------------------

    # Every definition (value or trait) as a {Definition}: kind, dtype, axes,
    # the rendered expression, the names it reads, and the names that read it.
    #
    # @return [Hash{Symbol => Definition}]
    def definitions
      @definitions ||= build_definitions
    end

    # @return [Definition, nil]
    def definition(name)
      definitions[name.to_sym]
    end

    # @return [Array<Symbol>] all definition names (values and traits)
    def definition_names
      definitions.keys
    end

    # @return [Array<Symbol>] names of `value` definitions
    def value_names
      definitions.select { |_, d| d.kind == :value }.keys
    end

    # @return [Array<Symbol>] names of `trait` definitions
    def trait_names
      definitions.select { |_, d| d.kind == :trait }.keys
    end

    # @return [Array<Symbol>] definitions that reduce to a scalar (no axes)
    def scalar_definitions
      definitions.select { |_, d| d.axes.empty? }.keys
    end

    # @return [Array<Symbol>] definitions that broadcast over one or more axes
    def vector_definitions
      definitions.reject { |_, d| d.axes.empty? }.keys
    end

    # Order in which definitions are evaluated (a topological sort of the
    # dependency relation).
    #
    # @return [Array<Symbol>]
    def evaluation_order
      Array(@state[:evaluation_order])
    end

    # Names this definition reads directly (inputs and other definitions).
    #
    # @return [Array<Symbol>]
    def reads(name)
      definition(name)&.reads || []
    end

    # Names that read this input or definition directly.
    #
    # @return [Array<Symbol>]
    def read_by(name)
      Array(@state.dig(:dependents, name.to_sym))
    end

    # ---- imports ------------------------------------------------------------

    # Names imported from other schemas (inlined at compile time).
    #
    # @return [Array<Symbol>]
    def imported_names
      Array(@state[:imported_declarations]&.keys)
    end

    # ---- serialization ------------------------------------------------------

    # Backwards-compatible alias: the output declarations keyed by name with
    # `{ kind:, type:, axes: }`. Prefer {#definitions}.
    #
    # @return [Hash{Symbol => Hash}]
    def outputs
      @state[:output_schema] || {}
    end

    # @return [Array<Symbol>]
    def output_names = outputs.keys

    # @return [Array<Symbol>]
    def array_outputs = vector_definitions

    # @return [Array<Symbol>]
    def scalar_outputs = scalar_definitions

    # @return [Array<Symbol>]
    def axes_for(name)
      d = definition(name)
      raise KeyError, "Unknown definition: #{name}" unless d

      d.axes
    end

    # Per-declaration hints (the configurable-codegen seam).
    #
    # @return [Hash{Symbol => Hash}]
    def hints
      @state[:hints] || {}
    end

    # Total, JSON-safe snapshot of the whole algebra. Safe to hand to a frontend,
    # persist, or give to an LLM as a tool-use contract.
    #
    # @return [Hash]
    def to_h
      {
        inputs: input_fields.map(&:to_h),
        definitions: definitions.values.map(&:to_h),
        evaluation_order: evaluation_order,
        imports: imported_names,
        hints: hints
      }
    end

    # Human/LLM-readable rendering of the algebra.
    #
    # @return [String]
    def to_s
      Printer.new(self).render
    end
    alias to_str to_s
    alias inspect to_s

    private

    def build_definitions
      decls = @state[:declarations] || {}
      out = @state[:output_schema] || {}
      deps = @state[:dependencies] || {}
      dependents = @state[:dependents] || {}

      decls.each_with_object({}) do |(name, decl), acc|
        meta = out[name] || {}
        acc[name] = Definition.new(
          name: name,
          kind: meta[:kind] || (decl.is_a?(Kumi::Syntax::TraitDeclaration) ? :trait : :value),
          type: meta[:type]&.to_s,
          axes: Array(meta[:axes]),
          expression: Core::ExpressionRenderer.render(decl.expression),
          reads: Array(deps[name]).map(&:to).uniq,
          read_by: Array(dependents[name])
        )
      end
    end

    def build_input_field(leaf, plans)
      plan = plans[leaf[:path].join(".")]
      InputField.new(
        path: leaf[:path],
        type: leaf[:type],
        domain: leaf[:domain],
        axes: plan ? Array(plan[:loop_axes]) : [],
        element_path: plan ? Array(plan[:tail_keys_after_last_loop]) : leaf[:path]
      )
    end

    CONTAINER_KINDS = %i[array hash].freeze
    private_constant :CONTAINER_KINDS

    def walk_input_nodes(nodes, path, acc)
      nodes.each do |name, node|
        child_path = path + [name]
        if CONTAINER_KINDS.include?(node.container)
          walk_input_nodes(node.children || {}, child_path, acc)
        else
          acc << { path: child_path, type: node.type, domain: node.domain }
        end
      end
    end

    def node_to_tree(node)
      base = { type: node.type, container: node.container }
      base[:domain] = node.domain if node.domain
      base[:children] = node.children.transform_values { |c| node_to_tree(c) } if node.children
      base
    end
  end
end

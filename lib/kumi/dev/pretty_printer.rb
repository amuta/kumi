# frozen_string_literal: true

require "json"
require "stringio"
require_relative "printer/irv2_formatter"

module Kumi
  module Dev
    module PrettyPrinter
      module_function

      def run(kind, path)
        method_name = "generate_#{kind}"
        raise "Unknown pretty print kind: #{kind}" unless respond_to?(method_name)

        output = send(method_name, path)
        puts output if output
      end

      def with_stop_after(pass_name)
        saved = {
          "KUMI_STOP_AFTER" => ENV.fetch("KUMI_STOP_AFTER", nil),
          "KUMI_CHECKPOINT" => ENV.fetch("KUMI_CHECKPOINT", nil),
          "KUMI_RESUME_FROM" => ENV.fetch("KUMI_RESUME_FROM", nil),
          "KUMI_RESUME_AT" => ENV.fetch("KUMI_RESUME_AT", nil)
        }

        ENV["KUMI_STOP_AFTER"] = pass_name
        ENV["KUMI_CHECKPOINT"] = "0"
        ENV.delete("KUMI_RESUME_FROM")
        ENV.delete("KUMI_RESUME_AT")

        yield
      ensure
        saved.each { |k, v| v ? ENV[k] = v : ENV.delete(k) }
      end

      def generate_ast(path)
        schema, = Kumi::Frontends.load(path: path)
        Kumi::Support::SExpressionPrinter.print(schema)
      end

      def generate_input_plan(path)
        res = analyze_schema(path, stop_after: "InputAccessPlannerPass")
        return nil unless res.state[:input_metadata]

        print_input_plan(res.state[:input_metadata])
      end

      def print_input_plan(metadata, indent = 0)
        lines = []
        metadata.each do |name, node|
          lines << format_node(name, node, indent)
        end
        lines.join("\n")
      end

      def format_node(name, node, indent)
        prefix = "  " * indent
        result = []

        # Node header with type and container
        header = "#{prefix}#{name}: #{node.type}"
        header += " (#{node.container})" if node.container != :scalar
        header += " access_mode=#{node.access_mode}" if node.access_mode
        result << header

        # Child steps if any
        if node.child_steps && !node.child_steps.empty?
          node.child_steps.each do |child_name, steps|
            steps_str = steps.map { |s| s[:kind] }.join(" → ")
            result << "#{prefix}  └─> #{child_name}: #{steps_str}"
          end
        end

        # Recursively print children
        if node.children && !node.children.empty?
          node.children.each do |child_name, child_node|
            result << format_node(child_name, child_node, indent + 1)
          end
        end

        result.join("\n")
      end

      def generate_ir(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema)
        return nil unless res.state[:ir_module]

        Kumi::Support::IRRender.to_text(res.state[:ir_module], analysis_state: res.state)
      end

      def generate_nast(path)
        res = analyze_schema(path, stop_after: "NormalizeToNASTPass")
        mod = res.state[:nast_module] or raise "Missing NAST for #{path}"
        Kumi::Support::NASTPrinter.print(mod)
      end

      def generate_snast(path)
        res = analyze_schema(path, stop_after: "SNASTPass")
        mod = res.state[:snast_module] or raise "Missing SNAST for #{path}"
        Kumi::Support::SNASTPrinter.print(mod)
      end

      # The IR-graph stages differ only in the pass to stop after and the state
      # key to render — one row each instead of a copy-pasted method. :label is
      # what the "Missing …" diagnostic prints.
      IR_GRAPH_STAGES = {
        dfir: { stop_after: "DFValidatePass", state_key: :df_module_unoptimized, label: "DFIR" },
        dfir_optimized: { stop_after: "DFValidatePass", state_key: :df_module, label: "optimized DFIR" },
        vecir: { stop_after: "VecValidatePass", state_key: :vec_module, label: "VecIR" },
        loopir: { stop_after: "LoopValidatePass", state_key: :loop_module, label: "LoopIR" }
      }.freeze

      # Stages that run the full analyzer (side tables on) and render one state
      # key. :render maps the state value to text.
      ANALYZED_STAGES = {
        irv2: { state_key: :irv2, render: ->(v) { Printer::WidthAwareJson.dump(v) } },
        binding_manifest: { state_key: :binding_manifest, render: ->(v) { Printer::WidthAwareJson.dump(v) } },
        schema_ruby: { state_key: :ruby_codegen_files, render: ->(v) { v["codegen.rb"] } },
        schema_javascript: { state_key: :javascript_codegen_files, render: ->(v) { v["codegen.mjs"] } }
      }.freeze

      # define_method under `module_function` mode (above) exports these as
      # callable module methods, same as the literal `def generate_*` forms.
      IR_GRAPH_STAGES.each_key do |kind|
        define_method(:"generate_#{kind}") { |path| generate_ir_graph(path, **IR_GRAPH_STAGES[kind]) }
      end

      ANALYZED_STAGES.each_key do |kind|
        define_method(:"generate_#{kind}") { |path| generate_analyzed(path, **ANALYZED_STAGES[kind]) }
      end

      def generate_ir_graph(path, stop_after:, state_key:, label:)
        res = analyze_schema(path, stop_after: stop_after, side_tables: true)
        graph = res.state[state_key] or raise "Missing #{label} for #{path}"
        print_ir_graph(graph)
      end

      def generate_analyzed(path, state_key:, render:)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema, side_tables: true)
        value = res.state[state_key] or return nil
        render.call(value)
      end

      # Executes the generated Ruby + JS against the golden's input.json and
      # snapshots the outputs (also asserting Ruby == JS). Returns nil when the
      # golden has no input.json (text-only). See GoldenRuntime.
      def generate_runtime(path)
        require_relative "golden_runtime"
        GoldenRuntime.snapshot(path)
      end

      def generate_planning(path)
        require_relative "../codegen/planning"

        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema, side_tables: true)
        return nil unless res.state[:irv2]

        bundle = Kumi::Codegen::Planning.from_ir(res.state[:irv2])
        planning_data = Kumi::Codegen::Planning.to_json(bundle)
        Printer::WidthAwareJson.dump(planning_data)
      end

      def generate_pack(path)
        require_relative "../pack"

        Kumi::Pack.print(schema: path, targets: %w[ruby])
      end

      def print_ir_graph(graph)
        io = StringIO.new
        Kumi::IR::Printer.print(graph, io: io)
        io.string
      end

      def analyze_schema(path, stop_after: nil, **opts)
        schema, = Kumi::Frontends.load(path: path)
        if stop_after
          with_stop_after(stop_after) do
            Kumi::Analyzer.analyze!(schema, **opts)
          end
        else
          Kumi::Analyzer.analyze!(schema, **opts)
        end
      end
    end
  end
end

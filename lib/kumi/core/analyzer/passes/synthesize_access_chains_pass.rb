# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Builds canonical IR input plans directly from input_table (chain-free).
        #
        # Input (state[:input_table]):
        #   {
        #     [:a, :b] => {
        #       axes:       ["a"],                 # optional; if missing we derive from axis_loops
        #       dtype:      :array|:integer|...,
        #       key_policy: :indifferent,          # optional (falls back to terminal.key_policy or default)
        #       on_missing: :error,                # optional (falls back to terminal.on_missing or default)
        #       axis_loops: [                      # authoritative physical loop steps
        #         { axis: :a, path: [:a], loop_idx: 0, kind: "array_field", key: "a" }, ...
        #       ],
        #       leaf_nav:   [ { "kind" => "field_leaf", "key" => "price" } ],
        #       terminal:   { "dtype" => "integer", "key_policy" => "indifferent", "on_missing" => "error" },
        #       path_fqn:   "a.b"
        #     },
        #     ...
        #   }
        #
        # Output (state[:ir_input_plans]):
        #   [ Core::IRV2::InputPlan.new(...) ]   # embeds axis_loops & leaf_nav; no chains anywhere
        class SynthesizeAccessChainsPass < PassBase
          def run(_errors)
            input_table = get_state(:input_table, required: true)

            plans = input_table
              .sort_by { |(path, _)| path.map(&:to_s).join(".") } # deterministic
              .map { |path, info| build_input_plan(path, info) }

            debug "Generated #{plans.size} input plans (chain-free)"
            state.with(:ir_input_plans, plans.freeze)
          end

          private

          def build_input_plan(source_path, info)
            # Normalize hashes coming from earlier passes (may be string-keyed)
            axis_loops = Array(info[:axis_loops] || info["axis_loops"]).map { |h| symdeep(h) }
            leaf_nav   = Array(info[:leaf_nav]   || info["leaf_nav"]).map   { |h| symdeep(h) }
            terminal   = symdeep(info[:terminal] || info["terminal"] || { kind: :none })

            # Axes: prefer explicit, else derive from axis_loops
            explicit_axes = info[:axes] || info["axes"]
            axes = (explicit_axes ? Array(explicit_axes) : axis_loops.map { |l| l[:axis] }).map(&:to_sym)

            dtype = (info[:dtype] || info["dtype"])
            key_policy = (info[:key_policy] || info["key_policy"] ||
                          terminal[:key_policy] || :indifferent).to_sym
            missing_policy = (info[:on_missing] || info["on_missing"] ||
                              terminal[:on_missing] || :error).to_sym
            path_fqn = (info[:path_fqn] || info["path_fqn"] ||
                        source_path.map(&:to_s).join(".")).to_s

            Core::IRV2::InputPlan.new(
              source_path: source_path,     # Array<Symbol>
              axes: axes,                   # Array<Symbol>
              dtype: dtype,                 # Symbol or String (kept as provided)
              key_policy: key_policy,       # Symbol
              missing_policy: missing_policy, # Symbol
              axis_loops: axis_loops,       # Array<Hash>
              leaf_nav: leaf_nav,           # Array<Hash>
              terminal: terminal,           # Hash
              path_fqn: path_fqn            # String
            )
          end

          def symdeep(obj)
            case obj
            when Hash
              obj.each_with_object({}) do |(k, v), h|
                h[k.to_sym] = symdeep(v)
              end
            when Array
              obj.map { |v| symdeep(v) }
            else
              obj
            end
          end
        end
      end
    end
  end
end
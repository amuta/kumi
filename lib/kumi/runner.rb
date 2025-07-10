# frozen_string_literal: true

module Kumi
  Runner = Struct.new(:context, :schema, :dependency_graph) do
    def slice(*keys)
      schema.evaluate(context, *keys)
    end

    def fetch(key)
      schema.evaluate_binding(key, context)
    end

    def explain(key, indent = 0)
      # Get the final value for the key we are explaining
      final_value = fetch(key)

      # Find the direct dependencies for this key from the analysis
      deps = dependency_graph[key] || []

      # Format the output string
      output = ("  " * indent) + "-> #{key.inspect} evaluated to: #{final_value.inspect}"

      if deps.any?
        output += " (derived from: #{deps.to_a.join(', ')})"
        # Recursively explain each dependency
        deps.each do |dep_key|
          output += "\n#{explain(dep_key, indent + 1)}"
        end
      end

      output
    end
  end
end

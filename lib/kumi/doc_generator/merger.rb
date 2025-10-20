module Kumi
  module DocGenerator
    class Merger
      def initialize(loader)
        @loader = loader
      end

      def merge
        functions = @loader.load_functions
        kernels = @loader.load_kernels

        result = {}

        functions.each do |fn|
          aliases = fn['aliases'] || []
          aliases.each do |alias_name|
            result[alias_name] = build_doc_entry(fn, kernels)
          end
        end

        result
      end

      private

      def build_doc_entry(function, kernels)
        kernel_map = {}
        kernels.each do |kernel|
          if kernel['fn'] == function['id']
            target = extract_target(kernel['id'])
            kernel_map[target] = kernel
          end
        end

        {
          'id' => function['id'],
          'kind' => function['kind'],
          'params' => function['params'] || [],
          'arity' => (function['params'] || []).length,
          'kernels' => kernel_map,
          'dtype' => function['dtype'],
          'aliases' => function['aliases'] || [],
          'reduction_strategy' => function['reduction_strategy']
        }
      end

      def extract_target(kernel_id)
        # kernel_id format: "agg.sum:ruby:v1" -> "ruby"
        parts = kernel_id.split(':')
        parts[1] if parts.length >= 2
      end
    end
  end
end

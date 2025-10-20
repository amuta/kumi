require 'json'

module Kumi
  module DocGenerator
    module Formatters
      class Json
        def initialize(docs)
          @docs = docs
        end

        def format
          enriched = @docs.each_with_object({}) do |(alias_name, entry), acc|
            kernel_ids = extract_kernel_ids(entry['kernels'])
            acc[alias_name] = {
              'id' => entry['id'],
              'kind' => entry['kind'],
              'arity' => entry['arity'],
              'params' => entry['params'],
              'kernels' => kernel_ids,
              'dtype' => entry['dtype'],
              'aliases' => entry['aliases'],
              'reduction_strategy' => entry['reduction_strategy']
            }
          end

          JSON.pretty_generate(enriched)
        end

        private

        def extract_kernel_ids(kernels)
          kernels.each_with_object({}) do |(target, kernel), acc|
            acc[target] = kernel.is_a?(Hash) ? kernel['id'] : kernel
          end
        end
      end
    end
  end
end

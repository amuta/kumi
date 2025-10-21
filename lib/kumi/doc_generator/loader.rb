require "yaml"

module Kumi
  module DocGenerator
    class Loader
      def initialize(functions_dir: nil, kernels_dir: nil)
        @functions_dir = functions_dir
        @kernels_dir = kernels_dir
      end

      def load_functions
        return [] unless @functions_dir

        load_yaml_dir(@functions_dir)
      end

      def load_kernels
        return [] unless @kernels_dir

        load_yaml_dir(@kernels_dir)
      end

      private

      def load_yaml_dir(dir_path)
        result = []
        Dir.glob(File.join(dir_path, "**/*.yaml")).each do |file|
          data = YAML.load_file(file)
          if data && data["functions"]
            result.concat(data["functions"])
          elsif data && data["kernels"]
            result.concat(data["kernels"])
          end
        end
        result
      end
    end
  end
end

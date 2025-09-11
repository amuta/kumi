# frozen_string_literal: true

require "yaml"

module Kumi
  module RegistryV2
    module Loader
      module_function

      # { "core.mul" => Function(id: "core.mul", kind: :elementwise, params: [...]) }
      def load_functions(dir, func_struct)
        files = Dir.glob(File.join(dir, "**", "*.y{a,}ml")).sort
        funcs = files.flat_map { |p| (YAML.load_file(p) || {}).fetch("functions", []) }
        # funcs.each_with_object({}) do |h, acc|
        #   acc[h.fetch("id").to_s] = {
        #     kind: h.fetch("kind").to_s.to_sym,
        #     aliases: Array(h["aliases"]).map!(&:to_s),
        #     params: h.fetch("params")
        #   }
        # end
        funcs.each_with_object({}) do |h, acc|
          f = func_struct.new(
            id: h.fetch("id").to_s,
            kind: h.fetch("kind").to_s.to_sym,
            aliases: Array(h["aliases"]).map!(&:to_s),
            params: h.fetch("params"),
            dtype: h["dtype"],
            expand: h["expand"]
          )
          raise "duplicate function id `#{f.id}`" if acc.key?(f.id)

          acc[f.id] = f
        end
      end

      # { ["core.mul", :ruby] => Kernel }
      def load_kernels(root, kernel_struct)
        targets = Dir.glob(File.join(root, "*")).select { |p| File.directory?(p) }.map { |p| File.basename(p).to_sym }
        out = {}
        targets.each do |t|
          Dir.glob(File.join(root, t.to_s, "**", "*.y{a,}ml")).sort.each do |p|
            (YAML.load_file(p) || {}).fetch("kernels", []).each do |h|
              k = kernel_struct.new(
                id: h.fetch("id"),
                fn_id: h.fetch("fn").to_s,
                target: t,
                impl: h["impl"],
                identity: h["identity"]
              )
              key = [k.fn_id, t]
              raise "duplicate kernel for #{key}" if out.key?(key)

              out[key] = k
            end
          end
        end
        out
      end
    end
  end
end

module Kumi::Core::Functions
  class RegistryV2
    def initialize(functions:)
      @by_name = functions.group_by(&:name).transform_values { |v| v.sort_by(&:opset).freeze }.freeze
    end

    def fetch(name, opset: nil)
      list = @by_name[name] or raise KeyError, "unknown function #{name}"
      opset ? list.find { |f| f.opset == opset } : list.last
    end

    # very small resolver; we’ll keep rules simple for v0
    def choose_signature(fn, arg_shapes)
      fn.signatures.find { |sig| Shape.unify_args_with_signature(arg_shapes, sig) } or
        raise ArgumentError, "no matching signature for #{fn.name} with shapes #{arg_shapes.inspect}"
    end

    def resolve_kernel(fn, backend:, conditions: {})
      ks = fn.kernels.select { |k| k.backend == backend.to_sym }
      ks = ks.select { |k| conditions.all? { |ck, cv| k.when_&.fetch(ck, cv) == cv } } unless conditions.empty?
      ks.max_by(&:priority) or raise "no kernel for #{fn.name} backend=#{backend}"
    end
  end
end
